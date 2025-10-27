`include "constants.vh"

module top_level (
    input         clk,
    input         reset_n,
    output [15:0] LCD_DATA,
    output        LCD_WR,
    output        LCD_RS,
    output        LCD_CS,
    output        LCD_RESET,
    output        LCD_BL,
    output        LCD_RDX,
    output        led_1,
    output  [7:0] la_out
);

reg led_1_reg;
assign led_1 = led_1_reg;
reg  [15:0] pixel_data;
reg  update_screen;
reg  init_done;
reg [31:0] data_count;
reg  start_read_data;
reg cmd_done;
reg cmd_data_done;
reg cmd_ndata_done;
reg  [15:0] x_start, x_end, y_start, y_end;
reg  [4:0] state;
reg  [31:0] delay_counter;
reg  [4:0] lcd_state;

// Сигнали для BRAM
wire bram_douta;
reg [17:0] bram_addra;

wire clk_main;
clk_wiz_1 main_clk_pll (
    .clk_in1(clk),
    .resetn(reset_n),
    .clk_out1(clk_main)
);

// ✅ FSM States
localparam S_INIT = 0, S_IDLE = 1, S_PREP_DRAW = 2, S_TRIGGER_WAIT = 3, S_DISPLAY = 4, S_DONE_DRAW = 5;

// ✅ Основні регістри
reg edit_mode = 0;
reg [2:0] selected_digit = 3'b111;
reg [3:0] number [0:4];
initial begin
    number[0] = 0; number[1] = 1; number[2] = 2; number[3] = 3; number[4] = 4;
end
reg need_update;
reg solid_fill;
reg [15:0] solid_color;
reg [17:0] bram_base_addra;
reg [5:0] draw_step;
assign la_out[4:0] = draw_step[4:0];
assign la_out[5] = clk_main;
assign la_out[6] = need_update;

reg screen_filled;

// ✅ BRAM
blk_mem_gen_0 bram (
    .clka(clk_main),
    .addra(bram_addra),
    .douta(bram_douta)
);

// ✅ LCD instance
lcd lcd_inst (
    .clk(clk_main),
    .reset_n(reset_n),
    .fill_color(pixel_data),
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
    .start_read_data(start_read_data),
    .cmd_done(cmd_done),
    .cmd_data_done(cmd_data_done),
    .cmd_ndata_done(cmd_ndata_done),
    .lcd_clk(lcd_clk),
    .lcd_state(lcd_state),
    .init_done(init_done),
    .lcd_data_count(data_count)
);

// ✅ NEW: Блок для оновлення екрану 60 Гц
reg [31:0] refresh_counter;
always @(posedge clk_main or negedge reset_n) begin
    if (!reset_n) begin
        refresh_counter <= 0;
        need_update <= 0; // Початкове значення 0 до завершення ініціалізації
    end else begin
        if (init_done) begin // Активуємо оновлення лише після init_done
            if (refresh_counter >= SCREEN_REFRESH_TICKS - 1) begin
                refresh_counter <= 0;
                need_update <= 1; // Тригер оновлення кожні 16.67 мс
                led_1_reg <= ~led_1_reg;
            end else begin
                refresh_counter <= refresh_counter + 1;
                if (draw_step == 36) need_update <= 0; // Скидання need_update після завершення циклу
            end
        end
    end
end

// ✅ Pixel data
assign pixel_data = solid_fill ? solid_color : (bram_douta ? TEXT_COLOR : TEXT_BACK_COLOR);

// ✅ MAIN FSM (36 steps)
always @(posedge clk_main or negedge reset_n) begin
    if (!reset_n) begin
        bram_addra <= 0;
        state <= S_INIT;
        update_screen <= 0;
        x_start <= 0; x_end <= DISPLAY_WIDTH - 1;
        y_start <= 0; y_end <= DISPLAY_HEIGH - 1;
        delay_counter <= 0;
        draw_step <= 0;
        solid_fill <= 0;
        //need_update <= 0;
        screen_filled <= 0;
    end else begin
        case (state)
            S_INIT: if (init_done) state <= S_IDLE;
            S_IDLE: begin
                if (need_update) begin
                    draw_step <= 0;
                    state <= S_PREP_DRAW;
                end
            end
            S_PREP_DRAW: begin
                solid_fill <= 0;
                update_screen <= 0;
                case (draw_step)
                    0: begin
                        screen_filled <= 1;
                        solid_fill <= 1; solid_color <= TEXT_BACK_COLOR;
                        x_start <= 0; x_end <= DISPLAY_WIDTH - 1;
                        y_start <= 0; y_end <= DISPLAY_HEIGH - 1;
                        state <= S_TRIGGER_WAIT;
                    end
                    1: begin bram_base_addra <= number[0] * (DIGIT_WIDTH * DIGIT_HEIGHT);
                        x_start <= DIGIT_X_START[0]; x_end <= DIGIT_X_START[0] + DIGIT_WIDTH - 1;
                        y_start <= DIGIT_Y; y_end <= DIGIT_Y + DIGIT_HEIGHT - 1; state <= S_TRIGGER_WAIT; end
                    2: begin bram_base_addra <= number[1] * (DIGIT_WIDTH * DIGIT_HEIGHT);
                        x_start <= DIGIT_X_START[1]; x_end <= DIGIT_X_START[1] + DIGIT_WIDTH - 1;
                        y_start <= DIGIT_Y; y_end <= DIGIT_Y + DIGIT_HEIGHT - 1; state <= S_TRIGGER_WAIT; end
                    3: begin bram_base_addra <= number[2] * (DIGIT_WIDTH * DIGIT_HEIGHT);
                        x_start <= DIGIT_X_START[2]; x_end <= DIGIT_X_START[2] + DIGIT_WIDTH - 1;
                        y_start <= DIGIT_Y; y_end <= DIGIT_Y + DIGIT_HEIGHT - 1; state <= S_TRIGGER_WAIT; end
                    4: begin bram_base_addra <= number[3] * (DIGIT_WIDTH * DIGIT_HEIGHT);
                        x_start <= DIGIT_X_START[3]; x_end <= DIGIT_X_START[3] + DIGIT_WIDTH - 1;
                        y_start <= DIGIT_Y; y_end <= DIGIT_Y + DIGIT_HEIGHT - 1; state <= S_TRIGGER_WAIT; end
                    5: begin bram_base_addra <= number[4] * (DIGIT_WIDTH * DIGIT_HEIGHT);
                        x_start <= DIGIT_X_START[4]; x_end <= DIGIT_X_START[4] + DIGIT_WIDTH - 1;
                        y_start <= DIGIT_Y; y_end <= DIGIT_Y + DIGIT_HEIGHT - 1; state <= S_TRIGGER_WAIT; end
                    6: begin bram_base_addra <= CHAR_BASE + 0 * (CHAR_WIDTH * CHAR_HEIGHT);
                        x_start <= BUTTON_X_EDIT_START;
                        x_end <= BUTTON_X_EDIT_START + CHAR_WIDTH - 1;
                        y_start <= BUTTON_Y_TOP;
                        y_end <= BUTTON_Y_TOP + CHAR_HEIGHT - 1;
                        state <= S_TRIGGER_WAIT;
                    end
                    7: begin bram_base_addra <= CHAR_BASE + 1 * (CHAR_WIDTH * CHAR_HEIGHT);
                        x_start <= BUTTON_X_EDIT_START + CHAR_WIDTH + CHAR_SPACING;
                        x_end <= BUTTON_X_EDIT_START + CHAR_WIDTH + CHAR_SPACING + CHAR_WIDTH - 1;
                        y_start <= BUTTON_Y_TOP;
                        y_end <= BUTTON_Y_TOP + CHAR_HEIGHT - 1;
                        state <= S_TRIGGER_WAIT;
                    end
                    8: begin bram_base_addra <= CHAR_BASE + 2 * (CHAR_WIDTH * CHAR_HEIGHT);
                        x_start <= BUTTON_X_EDIT_START + 2 * (CHAR_WIDTH + CHAR_SPACING);
                        x_end <= BUTTON_X_EDIT_START + 2 * (CHAR_WIDTH + CHAR_SPACING) + CHAR_WIDTH - 1;
                        y_start <= BUTTON_Y_TOP;
                        y_end <= BUTTON_Y_TOP + CHAR_HEIGHT - 1;
                        state <= S_TRIGGER_WAIT;
                    end
                    9: begin bram_base_addra <= CHAR_BASE + 3 * (CHAR_WIDTH * CHAR_HEIGHT);
                        x_start <= BUTTON_X_EDIT_START + 3 * (CHAR_WIDTH + CHAR_SPACING);
                        x_end <= BUTTON_X_EDIT_START + 3 * (CHAR_WIDTH + CHAR_SPACING) + CHAR_WIDTH - 1;
                        y_start <= BUTTON_Y_TOP;
                        y_end <= BUTTON_Y_TOP + CHAR_HEIGHT - 1;
                        state <= S_TRIGGER_WAIT;
                    end
                    10: begin bram_base_addra <= CHAR_BASE + 4 * (CHAR_WIDTH * CHAR_HEIGHT);
                        x_start <= BUTTON_X_SAVE_START;
                        x_end <= BUTTON_X_SAVE_START + CHAR_WIDTH - 1;
                        y_start <= BUTTON_Y_TOP;
                        y_end <= BUTTON_Y_TOP + CHAR_HEIGHT - 1;
                        state <= S_TRIGGER_WAIT;
                    end
                    11: begin bram_base_addra <= CHAR_BASE + 5 * (CHAR_WIDTH * CHAR_HEIGHT);
                        x_start <= BUTTON_X_SAVE_START + CHAR_WIDTH + CHAR_SPACING;
                        x_end <= BUTTON_X_SAVE_START + CHAR_WIDTH + CHAR_SPACING + CHAR_WIDTH - 1;
                        y_start <= BUTTON_Y_TOP;
                        y_end <= BUTTON_Y_TOP + CHAR_HEIGHT - 1;
                        state <= S_TRIGGER_WAIT;
                    end
                    12: begin bram_base_addra <= CHAR_BASE + 6 * (CHAR_WIDTH * CHAR_HEIGHT);
                        x_start <= BUTTON_X_SAVE_START + 2 * (CHAR_WIDTH + CHAR_SPACING);
                        x_end <= BUTTON_X_SAVE_START + 2 * (CHAR_WIDTH + CHAR_SPACING) + CHAR_WIDTH - 1;
                        y_start <= BUTTON_Y_TOP;
                        y_end <= BUTTON_Y_TOP + CHAR_HEIGHT - 1;
                        state <= S_TRIGGER_WAIT;
                    end
                    13: begin bram_base_addra <= CHAR_BASE + 7 * (CHAR_WIDTH * CHAR_HEIGHT);
                        x_start <= BUTTON_X_SAVE_START + 3 * (CHAR_WIDTH + CHAR_SPACING);
                        x_end <= BUTTON_X_SAVE_START + 3 * (CHAR_WIDTH + CHAR_SPACING) + CHAR_WIDTH - 1;
                        y_start <= BUTTON_Y_TOP;
                        y_end <= BUTTON_Y_TOP + CHAR_HEIGHT - 1;
                        state <= S_TRIGGER_WAIT;
                    end
                    14: begin
                        if (!edit_mode) draw_step <= 36;
                        else begin
                            solid_fill <= 1; solid_color <= FRAME_COLOR;
                            x_start <= DIGIT_X_START[0]; x_end <= DIGIT_X_START[0] + DIGIT_WIDTH - 1;
                            y_start <= FRAME_Y_TOP - FRAME_THICK; y_end <= FRAME_Y_TOP - 1; state <= S_TRIGGER_WAIT;
                        end
                    end
                    15: begin if (!edit_mode) draw_step <= 36;
                        else begin
                            solid_fill <= 1; solid_color <= FRAME_COLOR;
                            x_start <= DIGIT_X_START[0]; x_end <= DIGIT_X_START[0] + DIGIT_WIDTH - 1;
                            y_start <= FRAME_Y_BOTTOM; y_end <= FRAME_Y_BOTTOM + FRAME_THICK - 1; state <= S_TRIGGER_WAIT;
                        end
                    end
                    16: begin if (!edit_mode) draw_step <= 36;
                        else begin
                            solid_fill <= 1; solid_color <= FRAME_COLOR;
                            x_start <= DIGIT_X_START[0] - FRAME_THICK; x_end <= DIGIT_X_START[0] - 1;
                            y_start <= FRAME_Y_TOP; y_end <= FRAME_Y_BOTTOM - 1; state <= S_TRIGGER_WAIT;
                        end
                    end
                    17: begin if (!edit_mode) draw_step <= 36;
                        else begin
                            solid_fill <= 1; solid_color <= FRAME_COLOR;
                            x_start <= DIGIT_X_START[0] + DIGIT_WIDTH; x_end <= DIGIT_X_START[0] + DIGIT_WIDTH + FRAME_THICK - 1;
                            y_start <= FRAME_Y_TOP; y_end <= FRAME_Y_BOTTOM - 1; state <= S_TRIGGER_WAIT;
                        end
                    end
                    18: begin if (!edit_mode) draw_step <= 36;
                        else begin
                            solid_fill <= 1; solid_color <= FRAME_COLOR;
                            x_start <= DIGIT_X_START[1]; x_end <= DIGIT_X_START[1] + DIGIT_WIDTH - 1;
                            y_start <= FRAME_Y_TOP - FRAME_THICK; y_end <= FRAME_Y_TOP - 1; state <= S_TRIGGER_WAIT;
                        end
                    end
                    19: begin if (!edit_mode) draw_step <= 36;
                        else begin
                            solid_fill <= 1; solid_color <= FRAME_COLOR;
                            x_start <= DIGIT_X_START[1]; x_end <= DIGIT_X_START[1] + DIGIT_WIDTH - 1;
                            y_start <= FRAME_Y_BOTTOM; y_end <= FRAME_Y_BOTTOM + FRAME_THICK - 1; state <= S_TRIGGER_WAIT;
                        end
                    end
                    20: begin if (!edit_mode) draw_step <= 36;
                        else begin
                            solid_fill <= 1; solid_color <= FRAME_COLOR;
                            x_start <= DIGIT_X_START[1] - FRAME_THICK; x_end <= DIGIT_X_START[1] - 1;
                            y_start <= FRAME_Y_TOP; y_end <= FRAME_Y_BOTTOM - 1; state <= S_TRIGGER_WAIT;
                        end
                    end
                    21: begin if (!edit_mode) draw_step <= 36;
                        else begin
                            solid_fill <= 1; solid_color <= FRAME_COLOR;
                            x_start <= DIGIT_X_START[1] + DIGIT_WIDTH; x_end <= DIGIT_X_START[1] + DIGIT_WIDTH + FRAME_THICK - 1;
                            y_start <= FRAME_Y_TOP; y_end <= FRAME_Y_BOTTOM - 1; state <= S_TRIGGER_WAIT;
                        end
                    end
                    22: begin if (!edit_mode) draw_step <= 36;
                        else begin
                            solid_fill <= 1; solid_color <= FRAME_COLOR;
                            x_start <= DIGIT_X_START[2]; x_end <= DIGIT_X_START[2] + DIGIT_WIDTH - 1;
                            y_start <= FRAME_Y_TOP - FRAME_THICK; y_end <= FRAME_Y_TOP - 1; state <= S_TRIGGER_WAIT;
                        end
                    end
                    23: begin if (!edit_mode) draw_step <= 36;
                        else begin
                            solid_fill <= 1; solid_color <= FRAME_COLOR;
                            x_start <= DIGIT_X_START[2]; x_end <= DIGIT_X_START[2] + DIGIT_WIDTH - 1;
                            y_start <= FRAME_Y_BOTTOM; y_end <= FRAME_Y_BOTTOM + FRAME_THICK - 1; state <= S_TRIGGER_WAIT;
                        end
                    end
                    24: begin if (!edit_mode) draw_step <= 36;
                        else begin
                            solid_fill <= 1; solid_color <= FRAME_COLOR;
                            x_start <= DIGIT_X_START[2] - FRAME_THICK; x_end <= DIGIT_X_START[2] - 1;
                            y_start <= FRAME_Y_TOP; y_end <= FRAME_Y_BOTTOM - 1; state <= S_TRIGGER_WAIT;
                        end
                    end
                    25: begin if (!edit_mode) draw_step <= 36;
                        else begin
                            solid_fill <= 1; solid_color <= FRAME_COLOR;
                            x_start <= DIGIT_X_START[2] + DIGIT_WIDTH; x_end <= DIGIT_X_START[2] + DIGIT_WIDTH + FRAME_THICK - 1;
                            y_start <= FRAME_Y_TOP; y_end <= FRAME_Y_BOTTOM - 1; state <= S_TRIGGER_WAIT;
                        end
                    end
                    26: begin if (!edit_mode) draw_step <= 36;
                        else begin
                            solid_fill <= 1; solid_color <= FRAME_COLOR;
                            x_start <= DIGIT_X_START[3]; x_end <= DIGIT_X_START[3] + DIGIT_WIDTH - 1;
                            y_start <= FRAME_Y_TOP - FRAME_THICK; y_end <= FRAME_Y_TOP - 1; state <= S_TRIGGER_WAIT;
                        end
                    end
                    27: begin if (!edit_mode) draw_step <= 36;
                        else begin
                            solid_fill <= 1; solid_color <= FRAME_COLOR;
                            x_start <= DIGIT_X_START[3]; x_end <= DIGIT_X_START[3] + DIGIT_WIDTH - 1;
                            y_start <= FRAME_Y_BOTTOM; y_end <= FRAME_Y_BOTTOM + FRAME_THICK - 1; state <= S_TRIGGER_WAIT;
                        end
                    end
                    28: begin if (!edit_mode) draw_step <= 36;
                        else begin
                            solid_fill <= 1; solid_color <= FRAME_COLOR;
                            x_start <= DIGIT_X_START[3] - FRAME_THICK; x_end <= DIGIT_X_START[3] - 1;
                            y_start <= FRAME_Y_TOP; y_end <= FRAME_Y_BOTTOM - 1; state <= S_TRIGGER_WAIT;
                        end
                    end
                    29: begin if (!edit_mode) draw_step <= 36;
                        else begin
                            solid_fill <= 1; solid_color <= FRAME_COLOR;
                            x_start <= DIGIT_X_START[3] + DIGIT_WIDTH; x_end <= DIGIT_X_START[3] + DIGIT_WIDTH + FRAME_THICK - 1;
                            y_start <= FRAME_Y_TOP; y_end <= FRAME_Y_BOTTOM - 1; state <= S_TRIGGER_WAIT;
                        end
                    end
                    30: begin if (!edit_mode) draw_step <= 36;
                        else begin
                            solid_fill <= 1; solid_color <= FRAME_COLOR;
                            x_start <= DIGIT_X_START[4]; x_end <= DIGIT_X_START[4] + DIGIT_WIDTH - 1;
                            y_start <= FRAME_Y_TOP - FRAME_THICK; y_end <= FRAME_Y_TOP - 1; state <= S_TRIGGER_WAIT;
                        end
                    end
                    31: begin if (!edit_mode) draw_step <= 36;
                        else begin
                            solid_fill <= 1; solid_color <= FRAME_COLOR;
                            x_start <= DIGIT_X_START[4]; x_end <= DIGIT_X_START[4] + DIGIT_WIDTH - 1;
                            y_start <= FRAME_Y_BOTTOM; y_end <= FRAME_Y_BOTTOM + FRAME_THICK - 1; state <= S_TRIGGER_WAIT;
                        end
                    end
                    32: begin if (!edit_mode) draw_step <= 36;
                        else begin
                            solid_fill <= 1; solid_color <= FRAME_COLOR;
                            x_start <= DIGIT_X_START[4] - FRAME_THICK; x_end <= DIGIT_X_START[4] - 1;
                            y_start <= FRAME_Y_TOP; y_end <= FRAME_Y_BOTTOM - 1; state <= S_TRIGGER_WAIT;
                        end
                    end
                    33: begin if (!edit_mode) draw_step <= 36;
                        else begin
                            solid_fill <= 1; solid_color <= FRAME_COLOR;
                            x_start <= DIGIT_X_START[4] + DIGIT_WIDTH; x_end <= DIGIT_X_START[4] + DIGIT_WIDTH + FRAME_THICK - 1;
                            y_start <= FRAME_Y_TOP; y_end <= FRAME_Y_BOTTOM - 1; state <= S_TRIGGER_WAIT;
                        end
                    end
                    34: begin
                        if (!edit_mode || selected_digit == 3'b111) draw_step <= 36;
                        else begin
                            bram_base_addra <= ARROW_BASE + 0 * (ARROW_WIDTH * ARROW_HEIGHT);
                            x_start <= DIGIT_X_START[selected_digit];
                            x_end <= DIGIT_X_START[selected_digit] + ARROW_WIDTH - 1;
                            y_start <= FRAME_Y_TOP - ARROW_HEIGHT;
                            y_end <= FRAME_Y_TOP - 1;
                            state <= S_TRIGGER_WAIT;
                        end
                    end
                    35: begin
                        if (!edit_mode || selected_digit == 3'b111) draw_step <= 36;
                        else begin
                            bram_base_addra <= ARROW_BASE + 1 * (ARROW_WIDTH * ARROW_HEIGHT);
                            x_start <= DIGIT_X_START[selected_digit];
                            x_end <= DIGIT_X_START[selected_digit] + ARROW_WIDTH - 1;
                            y_start <= FRAME_Y_BOTTOM + 1;
                            y_end <= FRAME_Y_BOTTOM + ARROW_HEIGHT;
                            state <= S_TRIGGER_WAIT;
                        end
                    end
                    36: begin
                        draw_step <= 0;
                        //need_update <= 0;
                        state <= S_IDLE;
                    end
                endcase
            end
            S_TRIGGER_WAIT: begin
                update_screen <= 1;
                state <= S_DISPLAY;
            end
            S_DISPLAY: begin
                if (start_read_data) begin
                    if (!solid_fill) bram_addra <= bram_base_addra + data_count;
                end
                if (cmd_ndata_done) state <= S_DONE_DRAW;
            end
            S_DONE_DRAW: begin
                update_screen <= 0;
                draw_step <= draw_step + 1;
                state <= S_PREP_DRAW;
            end
        endcase
    end
end

endmodule