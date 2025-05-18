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
    output        led_1
);

wire key_ready;
wire [3:0] key_data_out;
wire [3:0] press_count;
reg  key_read;
reg  [15:0] fill_color;
reg  update_screen;
reg  [15:0] x_start, x_end, y_start, y_end;
wire [7:0] debug_port_1;
reg  init_screen; // Новий регістр для ініціалізації екрана

assign la_out[7:0] = debug_port_1;

lcd lcd_inst (
    .clk(clk),
    .reset_n(reset_n),
    .fill_color(RED),
    .x_start(0),
    .x_end(479),
    .y_start(0),
    .y_end(799),
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
    .led_2_reg(led_2)
);

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

always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        fill_color <= GREEN;
        key_read <= 0;
        update_screen <= 0;
        init_screen <= 1; // Активуємо ініціалізацію екрана після скидання
        x_start <= 0;
        x_end <= 479; // 480-1
        y_start <= 0;
        y_end <= 799; // 800-1
    end else begin
        if (init_screen) begin
            update_screen <= 1; // Запускаємо оновлення екрана
            init_screen <= 0;   // Скидаємо після одного такту
        end else if (key_ready && !key_read) begin
            key_read <= 1;
            case (key_data_out)
                4'h0: fill_color <= RED;
                4'h1: fill_color <= GREEN;
                4'h2: fill_color <= BLUE;
                4'h3: fill_color <= WHITE;
                4'h4: fill_color <= BLACK;
                4'h5: fill_color <= YELLOW;
                default: fill_color <= fill_color;
            endcase
            update_screen <= 1;
        end else if (key_read || update_screen) begin
            key_read <= 0;
            update_screen <= 0;
        end
    end
end

endmodule