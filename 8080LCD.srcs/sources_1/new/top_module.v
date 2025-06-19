`include "constants.vh"

module top_level (
    input         clk,
    input         reset_n,
    input  [3:0]  row_data_in,
    output [3:0]  col_data_out,
    output [15:0] LCD_DATA,
    output        LCD_WR,
    output        LCD_RS,
    output        LCD_CS,
    output        LCD_RESET,
    output        LCD_BL,
    output        LCD_RDX,
    output [7:0]  la_out,
    output        led_1,
    // Сигнали для XPT2046
    output        ts_clk,        // SPI такт (DCLK)
    output        ts_cs,         // SPI Chip Select (CS_N)
    input         ts_miso,       // SPI MISO (DOUT)
    output        ts_mosi,       // SPI MOSI (DIN)
    input         ts_pen,        // Сигнал переривання від XPT2046
    // Сигнали для SPI флеш
    //output        spi_sclk,      // SPI такт
    output        spi_cs_n,      // SPI Chip Select
    inout  [3:0]  spi_dq         // Бідирекційні піни DQ0-DQ3
);

wire key_ready;
wire [3:0] key_data_out;
wire [4:0] press_count;
reg  key_read;
reg  [15:0] fill_color;
reg  update_screen;
reg  [15:0] x_start, x_end, y_start, y_end;
wire [7:0] debug_port_1;
reg  init_screen;
reg  [2:0] state;
reg  [31:0] delay_counter;

// Сигнали для XPT2046
wire [11:0] x_value, y_value;
wire get_flag;
reg  touch_en;

// Сигнали для SPI флеш
reg  start;
reg  [23:0] addr = 24'h400000; // Початкова адреса зображення
reg  [15:0] num_bytes = 32768; // 32 КБ (128x128x2)
wire [7:0] data_out;
wire valid, done;

    assign la_out[5] = spi_sclk;
    assign la_out[4] = spi_cs_n;
    assign la_out[3:0] = spi_dq; 

// Сигнали для BRAM
wire [15:0] bram_douta, bram_doutb;
reg  [13:0] bram_addra, bram_addrb;
reg  [15:0] bram_dina;
reg  bram_wea, bram_web;
wire [15:0] pixel_data;

// FSM стани
localparam S_INIT = 0, S_READ_SPI = 1, S_WAIT_SPI = 2, S_DISPLAY = 3;

// BRAM інстанція
blk_mem_gen_0 bram_inst (
    .clka(clk),
    .wea(bram_wea),
    .addra(bram_addra),
    .dina(bram_dina),
    .douta(bram_douta),
    .clkb(clk),
    .web(bram_web),
    .addrb(bram_addrb),
    .dinb(16'h0),
    .doutb(bram_doutb)
);
STARTUPE2 #(
       .PROG_USR("FALSE"),
       .SIM_CCLK_FREQ(10.0)
    ) STARTUPE2_inst (
        .CFGCLK(),
        .CFGMCLK(),
        .EOS(end_of_startup),
        .PREQ(),
        .CLK(1'b0),
        .GSR(1'b0),
        .GTS(1'b0),
        .KEYCLEARB(1'b0),
        .PACK(1'b0),
        .USRCCLKO(spi_sclk),
        .USRCCLKTS(1'b0),
        .USRDONEO(1'b1),
        .USRDONETS(1'b1)
    );
// Quad SPI контролер
quad_spi_master #(
    .CLK_FREQ(50_000_000),
    .SPI_FREQ(10_000_000)
) spi_inst (
    .clk(clk),
    .rst(~reset_n),
    .start(start),
    .addr(addr),
    .num_bytes(num_bytes),
    .data_out(data_out),
    .valid(valid),
    .done(done),
    .sclk(spi_sclk),
    .cs_n(spi_cs_n),
    .dq_out(),
    .dq_oe(),
    .dq(spi_dq)
);

// LCD інстанція
lcd lcd_inst (
    .clk(clk),
    .reset_n(reset_n),
    .fill_color(pixel_data), // Використовуємо пікселі з BRAM
    .x_start(x_start),
    .x_end(x_end),
    .y_start(y_start),
    .y_end(y_end),
    .update_screen(update_screen),
    .LCD_DATA(LCD_DATA),
    .LCD_WR(LCD_WR),
    .LCD_RS(LCD_RS),
    .LCD_CS(LCD_CS),
    .LCD_RESET(LCD_RESET),
    .LCD_BL(LCD_BL),
    .LCD_RDX(LCD_RDX),
    .debug_port_1(debug_port_1),
    .led_1_reg(led_1),
    .led_2_reg()
);

// KeyPad інстанція
KeyPadInterpreter keypad_inst (
    .Clock(clk),
    .ResetButton(reset_n),
    .KeyRead(key_read),
    .RowDataIn(row_data_in),
    .KeyReady(key_ready),
    .DataOut(key_data_out),
    .ColDataOut(col_data_out),
    .PressCount(press_count)
);

// XPT2046 інстанція
xpt2046 touch_inst (
    .Clk50m(clk),
    .Rst_n(reset_n),
    .EN(touch_en),
    .X_Value(x_value),
    .Y_Value(y_value),
    .Get_Flag(get_flag),
    .PenIrq_n(ts_pen),
    .DCLK(ts_clk),
    .DIN(ts_mosi),
    .DOUT(ts_miso),
    .CS_N(ts_cs),
    .BUSY(1'b0)
);

// Логіка для сенсорного екрана
always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        touch_en <= 1'b0;
    end else begin
        touch_en <= 1'b1;
    end
end

// Логіка збору пікселів для BRAM
reg [7:0] data_buf;
reg pixel_valid;
reg [13:0] write_addr;

always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        start <= 0;
        pixel_valid <= 0;
        data_buf <= 0;
        write_addr <= 0;
        bram_wea <= 0;
        bram_dina <= 0;
    end else begin
        if (!start && !done && state == S_WAIT_SPI) begin
            start <= 1;
        end else begin
            start <= 0;
        end

        if (valid) begin
            if (!pixel_valid) begin
                data_buf <= data_out;
                pixel_valid <= 1;
            end else begin
                bram_dina <= {data_buf, data_out}; // Формуємо 16-бітний піксель
                bram_wea <= 1;
                bram_addra <= write_addr;
                write_addr <= write_addr + 1;
                pixel_valid <= 0;
            end
        end else begin
            bram_wea <= 0;
        end
    end
end

// FSM для керування
always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        state <= S_INIT;
        init_screen <= 1;
        update_screen <= 0;
        x_start <= 0;
        x_end <= 127; // 128-1
        y_start <= 0;
        y_end <= 127; // 128-1
        fill_color <= GREEN;
        key_read <= 0;
        delay_counter <= 0;
        bram_addrb <= 0;
        bram_web <= 0;
    end else begin
        case (state)
            S_INIT: begin
                if (init_screen) begin
                    update_screen <= 1;
                    init_screen <= 0;
                end else if (!update_screen) begin
                    state <= S_READ_SPI;
                end
            end
            S_READ_SPI: begin
                if (done) begin
                    state <= S_WAIT_SPI;
                    delay_counter <= 500_000_000; // 1 с затримки
                end
            end
            S_WAIT_SPI: begin
                if (delay_counter > 0) begin
                    delay_counter <= delay_counter - 1;
                end else begin
                    state <= S_DISPLAY;
                    update_screen <= 1;
                end
            end
            S_DISPLAY: begin
                update_screen <= 0;
                // Зчитування з BRAM для LCD
                bram_addrb <= bram_addrb + 1;
                if (bram_addrb == 16383) begin
                    bram_addrb <= 0;
                    update_screen <= 1;
                end
            end
        endcase
    end
end

assign pixel_data = bram_doutb;
//assign la_out = data_buf;

endmodule