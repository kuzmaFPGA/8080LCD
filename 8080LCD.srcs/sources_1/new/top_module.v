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
reg  init_done;
reg [31:0] data_count;
reg  start_read_data;
reg  [15:0] x_start, x_end, y_start, y_end;
wire [7:0] debug_port_1;
//reg  init_screen;
reg  [1:0] state;
reg  [31:0] delay_counter;
reg  [4:0]  lcd_state;
// Сигнали для XPT2046
wire [11:0] x_value, y_value;
wire get_flag;
reg  touch_en;

// Сигнали для BRAM
wire [15:0] bram_douta;
reg [13:0] bram_addra;
wire [15:0] pixel_data;

wire clk_main;

clk_wiz_1 main_clk_pll (
    .clk_in1(clk),
    .resetn(reset_n),
    .clk_out1(clk_main)
);

// FSM стани
localparam S_INIT = 0, S_WAIT = 1, S_TRIGGER_WAIT = 2, S_DISPLAY = 3;

blk_mem_gen_0 bram (
  .clka(clk),    // input wire clka
  .addra(bram_addra),  // input wire [13 : 0] addra
  .douta(bram_douta)  // output wire [15 : 0] douta
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
    .led_2_reg(),
    .start_read_data(start_read_data),
    .lcd_clk(lcd_clk),  // Підключаємо lcd_clk
    .lcd_state(lcd_state),
    .init_done(init_done),
    .lcd_data_count(data_count)
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

// FSM для керування
always @(posedge lcd_clk or negedge reset_n) begin
    if (!reset_n) begin
        bram_addra <= 0;
        state <= S_INIT;
        update_screen <= 0;
        x_start <= 0;
        x_end <= 127; // 128-1
        y_start <= 0;
        y_end <= 127; // 128-1
        fill_color <= GREEN;
        key_read <= 0;
        delay_counter <= 0;
    end else begin
        case (state)
            S_INIT: begin
                if (init_done) begin
                    state <= S_WAIT;
                    delay_counter <= 1 * MAIN_CLK_FREQ_KHZ; // 1 с затримки
                end
            end    
            S_WAIT: begin
                if (delay_counter > 0) begin
                    delay_counter <= delay_counter - 1;
                end else begin
                    state <= S_TRIGGER_WAIT;
                    update_screen <= 1;
                    delay_counter <= 10;
                end
            end
            S_TRIGGER_WAIT: begin
                if (delay_counter > 0) begin
                    delay_counter <= delay_counter - 1;
                end else begin
                    state <= S_DISPLAY;
                    bram_addra <= 0;
                end
            end
            S_DISPLAY: begin
                update_screen <= 0;
                if (start_read_data) begin
                    bram_addra <= data_count;
                    if (bram_addra == 16383) begin
                        bram_addra <= 0;
                        //delay_counter <= 1 * MAIN_CLK_FREQ_KHZ; // 1 с затримки
                        //state <= S_WAIT;
                    end
                end
            end
        endcase
    end
end
assign pixel_data = bram_douta;
//assign la_out[7:1] = bram_addra[7:1];
assign la_out[0:0] = start_read_data;
assign la_out[5:1] = lcd_state[4:0];
assign la_out[7:6] = state;

endmodule