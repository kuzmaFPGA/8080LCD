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
    input         ts_pen         // Сигнал переривання від XPT2046
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
reg  [1:0] state;
reg  [31:0] delay_counter;

// Сигнали для XPT2046
wire [11:0] x_value, y_value;
wire get_flag;
reg  touch_en;

// Сигнали для BRAM
wire [15:0] bram_douta, bram_doutb;
reg  [13:0] bram_addra, bram_addrb;
reg  [15:0] bram_dina;
reg  bram_wea, bram_web;
wire [15:0] pixel_data;

// FSM стани
localparam S_INIT = 0, S_WAIT = 1, S_DISPLAY = 2;

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

// Логіка для BRAM
always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        bram_wea <= 0;
        bram_dina <= 0;
        bram_addra <= 0;
    end else begin
        bram_wea <= 0; // Запис відключений, BRAM ініціалізовано файлом
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
                    state <= S_WAIT;
                    delay_counter <= 50_000_000; // 1 с затримки
                end
            end
            S_WAIT: begin
                if (delay_counter > 0) begin
                    delay_counter <= delay_counter - 1;
                end else begin
                    state <= S_DISPLAY;
                    update_screen <= 1;
                end
            end
            S_DISPLAY: begin
                update_screen <= 0;
                bram_addrb <= bram_addrb + 1;
                if (bram_addrb == 16383) begin
                    bram_addrb <= 0;
                end
            end
        endcase
    end
end

assign pixel_data = bram_doutb;
assign la_out = pixel_data[7:0]; // Вихід для дебагу не використовується

endmodule