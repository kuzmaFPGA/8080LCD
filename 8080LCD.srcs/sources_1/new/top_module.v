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
    output        ts_clk,
    output        ts_cs,
    input         ts_miso,
    output        ts_mosi,
    input         ts_pen,
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
reg  [4:0] lcd_state;

wire bram_douta;
reg [17:0] bram_addra;

wire clk_main;
clk_wiz_1 main_clk_pll (
    .clk_in1(clk),
    .resetn(reset_n),
    .clk_out1(clk_main)
);

// === FSM States ===
localparam S_INIT           = 0,
           S_IDLE           = 1,
           S_PREP_DRAW      = 2,
           S_TRIGGER_WAIT   = 3,
           S_DISPLAY        = 4,
           S_DONE_DRAW      = 5,
           S_INIT_FILL      = 6;

// === Тестовий маркер ===
localparam MARKER_SIZE   = 8;
localparam MARKER_COLOR  = 16'hF800;
localparam MARKER_BACK   = TEXT_BACK_COLOR;

// === Основні регістри ===
reg edit_mode = 0;
reg [3:0] selected_digit = 4'b1111;  // 0-7 або 1111
reg [3:0] number [0:7];
initial begin
    number[0] = 0; number[1] = 1; number[2] = 2; number[3] = 3;
    number[4] = 4; number[5] = 5; number[6] = 6; number[7] = 7;
end
reg need_update;
reg solid_fill;
reg [15:0] solid_color;
reg [17:0] bram_base_addra;
reg [6:0] draw_step;  // до 62
assign la_out[6:0] = draw_step[6:0];
assign la_out[7] = need_update;

reg init_fill_done;

// === Touch ===
wire [11:0] x_value, y_value;
wire get_flag;
reg touch_en;
reg [9:0] screen_x, screen_y;

// === Arrow update ===
reg [3:0] prev_selected_digit;
reg update_arrows_area;
reg [3:0] digit_to_update;

// === Маркер ===
reg marker_active;
reg [9:0] marker_x, marker_y;
reg update_marker;
reg marker_erase;

// === 60 Hz ===
reg [31:0] refresh_counter;

// === BRAM ===
blk_mem_gen_0 bram (
    .clka(clk_main),
    .addra(bram_addra),
    .douta(bram_douta)
);

// === LCD ===
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

// === XPT2046 ===
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

// === TOUCH ENABLE ===
always @(posedge clk or negedge reset_n) begin
    if (!reset_n) touch_en <= 1'b0;
    else          touch_en <= !ts_pen;
end

// === Touch mapping ===
always @(posedge clk_main or negedge reset_n) begin
    if (!reset_n) begin
        screen_x <= 0;
        screen_y <= 0;
    end else if (get_flag) begin
        if (ROTATE_90) begin
            screen_x <= (INVERT_X == 1) ? ((4095 - y_value) * DISPLAY_HEIGH >> 12) : ((y_value) * DISPLAY_HEIGH >> 12);
            screen_y <= (INVERT_X == 1) ? ((4095 - x_value) * DISPLAY_WIDTH >> 12) : ((x_value) * DISPLAY_WIDTH >> 12);
        end else begin
            screen_x <= (INVERT_X == 1) ? ((4095 - x_value) * DISPLAY_WIDTH >> 12) : ((x_value) * DISPLAY_WIDTH >> 12);
            screen_y <= (INVERT_X == 1) ? ((4095 - y_value) * DISPLAY_HEIGH >> 12) : ((y_value) * DISPLAY_HEIGH >> 12);
        end
    end
end

// === Touch + маркер + UI ===
always @(posedge clk_main or negedge reset_n) begin
    if (!reset_n) begin
        edit_mode <= 0;
        selected_digit <= 4'b1111;
        number[0] <= 0; number[1] <= 1; number[2] <= 2; number[3] <= 3;
        number[4] <= 4; number[5] <= 5; number[6] <= 6; number[7] <= 7;
        prev_selected_digit <= 4'b1111;
        update_arrows_area <= 0;
        digit_to_update <= 4'b1111;

        marker_active <= 0;
        marker_x <= 0;
        marker_y <= 0;
        update_marker <= 0;
        marker_erase <= 0;
    end else begin
        prev_selected_digit <= selected_digit;
        update_arrows_area <= 0;
        update_marker <= 0;
        marker_erase <= 0;

        if (get_flag) begin
            // === Маркер ===
            if (!marker_active || screen_x != marker_x || screen_y != marker_y) begin
                if (marker_active) marker_erase <= 1;
                marker_x <= screen_x;
                marker_y <= screen_y;
                marker_active <= 1;
                update_marker <= 1;
            end

            // === UI ===
            if (edit_mode) begin
                if (selected_digit != 4'b1111) begin
                    if (screen_x >= (DIGIT_X_START[selected_digit] ) && screen_x < (DIGIT_X_START[selected_digit]  + ARROW_WIDTH) &&
                        screen_y >= (FRAME_Y_TOP - ARROW_HEIGHT) && screen_y < FRAME_Y_TOP)
                        number[selected_digit] <= (number[selected_digit] == 9) ? 0 : number[selected_digit] + 1;
                    else if (screen_x >= (DIGIT_X_START[selected_digit] ) && screen_x < (DIGIT_X_START[selected_digit]  + ARROW_WIDTH) &&
                             screen_y >= FRAME_Y_BOTTOM && screen_y < (FRAME_Y_BOTTOM + ARROW_HEIGHT))
                        number[selected_digit] <= (number[selected_digit] == 0) ? 9 : number[selected_digit] - 1;
                end
                // Вибір цифри
                if      (screen_x >= DIGIT_X_START[0] && screen_x < DIGIT_X_START[0] + DIGIT_WIDTH && screen_y >= FRAME_Y_TOP && screen_y < FRAME_Y_BOTTOM) selected_digit <= 0;
                else if (screen_x >= DIGIT_X_START[1] && screen_x < DIGIT_X_START[1] + DIGIT_WIDTH && screen_y >= FRAME_Y_TOP && screen_y < FRAME_Y_BOTTOM) selected_digit <= 1;
                else if (screen_x >= DIGIT_X_START[2] && screen_x < DIGIT_X_START[2] + DIGIT_WIDTH && screen_y >= FRAME_Y_TOP && screen_y < FRAME_Y_BOTTOM) selected_digit <= 2;
                else if (screen_x >= DIGIT_X_START[3] && screen_x < DIGIT_X_START[3] + DIGIT_WIDTH && screen_y >= FRAME_Y_TOP && screen_y < FRAME_Y_BOTTOM) selected_digit <= 3;
                else if (screen_x >= DIGIT_X_START[4] && screen_x < DIGIT_X_START[4] + DIGIT_WIDTH && screen_y >= FRAME_Y_TOP && screen_y < FRAME_Y_BOTTOM) selected_digit <= 4;
                else if (screen_x >= DIGIT_X_START[5] && screen_x < DIGIT_X_START[5] + DIGIT_WIDTH && screen_y >= FRAME_Y_TOP && screen_y < FRAME_Y_BOTTOM) selected_digit <= 5;
                else if (screen_x >= DIGIT_X_START[6] && screen_x < DIGIT_X_START[6] + DIGIT_WIDTH && screen_y >= FRAME_Y_TOP && screen_y < FRAME_Y_BOTTOM) selected_digit <= 6;
                else if (screen_x >= DIGIT_X_START[7] && screen_x < DIGIT_X_START[7] + DIGIT_WIDTH && screen_y >= FRAME_Y_TOP && screen_y < FRAME_Y_BOTTOM) selected_digit <= 7;
            end else begin
                if (screen_x >= BUTTON_X_EDIT_START && screen_x < BUTTON_X_EDIT_END &&
                    screen_y >= BUTTON_Y_TOP && screen_y < BUTTON_Y_BOTTOM) edit_mode <= 1;
                else if (screen_x >= BUTTON_X_SAVE_START && screen_x < BUTTON_X_SAVE_END &&
                         screen_y >= BUTTON_Y_TOP && screen_y < BUTTON_Y_BOTTOM) begin
                    edit_mode <= 0;
                    selected_digit <= 4'b1111;
                end
            end
        end else begin
            if (marker_active) begin
                marker_erase <= 1;
                marker_active <= 0;
            end
        end

        // === Зміна digit ===
        if (edit_mode && prev_selected_digit != selected_digit && selected_digit != 4'b1111) begin
            update_arrows_area <= 1;
            digit_to_update <= prev_selected_digit;
        end
    end
end

// === 60 Hz ===
always @(posedge clk_main or negedge reset_n) begin
    if (!reset_n) begin
        refresh_counter <= 0;
        need_update <= 0;
    end else begin
        if (init_done) begin
            if (refresh_counter >= SCREEN_REFRESH_TICKS - 1) begin
                refresh_counter <= 0;
                need_update <= 1;
                led_1_reg <= ~led_1_reg;
            end else begin
                refresh_counter <= refresh_counter + 1;
                if (draw_step == 62) need_update <= 0;
            end
        end
    end
end

// === Pixel data ===
assign pixel_data = solid_fill ? solid_color : (bram_douta ? TEXT_COLOR : TEXT_BACK_COLOR);

// === MAIN FSM ===
always @(posedge clk_main or negedge reset_n) begin
    if (!reset_n) begin
        bram_addra <= 0;
        state <= S_INIT;
        update_screen <= 0;
        x_start <= 0; x_end <= DISPLAY_WIDTH - 1;
        y_start <= 0; y_end <= DISPLAY_HEIGH - 1;
        draw_step <= 0;
        solid_fill <= 0;
        init_fill_done <= 0;
    end else begin

        case (state)
            S_INIT: begin
                if (init_done && !init_fill_done) begin
                    solid_fill <= 1;
                    solid_color <= TEXT_BACK_COLOR;
                    x_start <= 0; x_end <= DISPLAY_WIDTH - 1;
                    y_start <= 0; y_end <= DISPLAY_HEIGH - 1;
                    state <= S_INIT_FILL;
                end else if (init_done) begin
                    init_fill_done <= 1;
                    state <= S_IDLE;
                end
            end

            S_INIT_FILL: begin
                update_screen <= 1;
                state <= S_TRIGGER_WAIT;
            end

            S_IDLE: begin
                update_screen <= 0;
                if (need_update) begin
                    draw_step <= 0;
                    state <= S_PREP_DRAW;
                end
            end

            S_PREP_DRAW: begin
                update_screen <= 0;
                solid_fill <= 0;
                case (draw_step)
                    0: draw_step <= 1;

                    // === 8 Цифр (1-8) ===
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
                    6: begin bram_base_addra <= number[5] * (DIGIT_WIDTH * DIGIT_HEIGHT);
                        x_start <= DIGIT_X_START[5]; x_end <= DIGIT_X_START[5] + DIGIT_WIDTH - 1;
                        y_start <= DIGIT_Y; y_end <= DIGIT_Y + DIGIT_HEIGHT - 1; state <= S_TRIGGER_WAIT; end
                    7: begin bram_base_addra <= number[6] * (DIGIT_WIDTH * DIGIT_HEIGHT);
                        x_start <= DIGIT_X_START[6]; x_end <= DIGIT_X_START[6] + DIGIT_WIDTH - 1;
                        y_start <= DIGIT_Y; y_end <= DIGIT_Y + DIGIT_HEIGHT - 1; state <= S_TRIGGER_WAIT; end
                    8: begin bram_base_addra <= number[7] * (DIGIT_WIDTH * DIGIT_HEIGHT);
                        x_start <= DIGIT_X_START[7]; x_end <= DIGIT_X_START[7] + DIGIT_WIDTH - 1;
                        y_start <= DIGIT_Y; y_end <= DIGIT_Y + DIGIT_HEIGHT - 1; state <= S_TRIGGER_WAIT; end

                    // === Кнопки (9-16) ===
                    9:  begin bram_base_addra <= CHAR_BASE + 0 * (CHAR_WIDTH * CHAR_HEIGHT); x_start <= BUTTON_X_EDIT_START; x_end <= BUTTON_X_EDIT_START + CHAR_WIDTH - 1; y_start <= BUTTON_Y_TOP; y_end <= BUTTON_Y_TOP + CHAR_HEIGHT - 1; state <= S_TRIGGER_WAIT; end
                    10: begin bram_base_addra <= CHAR_BASE + 1 * (CHAR_WIDTH * CHAR_HEIGHT); x_start <= BUTTON_X_EDIT_START + CHAR_WIDTH + CHAR_SPACING; x_end <= x_start + CHAR_WIDTH - 1; y_start <= BUTTON_Y_TOP; y_end <= BUTTON_Y_TOP + CHAR_HEIGHT - 1; state <= S_TRIGGER_WAIT; end
                    11: begin bram_base_addra <= CHAR_BASE + 2 * (CHAR_WIDTH * CHAR_HEIGHT); x_start <= BUTTON_X_EDIT_START + 2*(CHAR_WIDTH + CHAR_SPACING); x_end <= x_start + CHAR_WIDTH - 1; y_start <= BUTTON_Y_TOP; y_end <= BUTTON_Y_TOP + CHAR_HEIGHT - 1; state <= S_TRIGGER_WAIT; end
                    12: begin bram_base_addra <= CHAR_BASE + 3 * (CHAR_WIDTH * CHAR_HEIGHT); x_start <= BUTTON_X_EDIT_START + 3*(CHAR_WIDTH + CHAR_SPACING); x_end <= x_start + CHAR_WIDTH - 1; y_start <= BUTTON_Y_TOP; y_end <= BUTTON_Y_TOP + CHAR_HEIGHT - 1; state <= S_TRIGGER_WAIT; end
                    13: begin bram_base_addra <= CHAR_BASE + 4 * (CHAR_WIDTH * CHAR_HEIGHT); x_start <= BUTTON_X_SAVE_START; x_end <= BUTTON_X_SAVE_START + CHAR_WIDTH - 1; y_start <= BUTTON_Y_TOP; y_end <= BUTTON_Y_TOP + CHAR_HEIGHT - 1; state <= S_TRIGGER_WAIT; end
                    14: begin bram_base_addra <= CHAR_BASE + 5 * (CHAR_WIDTH * CHAR_HEIGHT); x_start <= BUTTON_X_SAVE_START + CHAR_WIDTH + CHAR_SPACING; x_end <= x_start + CHAR_WIDTH - 1; y_start <= BUTTON_Y_TOP; y_end <= BUTTON_Y_TOP + CHAR_HEIGHT - 1; state <= S_TRIGGER_WAIT; end
                    15: begin bram_base_addra <= CHAR_BASE + 6 * (CHAR_WIDTH * CHAR_HEIGHT); x_start <= BUTTON_X_SAVE_START + 2*(CHAR_WIDTH + CHAR_SPACING); x_end <= x_start + CHAR_WIDTH - 1; y_start <= BUTTON_Y_TOP; y_end <= BUTTON_Y_TOP + CHAR_HEIGHT - 1; state <= S_TRIGGER_WAIT; end
                    16: begin bram_base_addra <= CHAR_BASE + 7 * (CHAR_WIDTH * CHAR_HEIGHT); x_start <= BUTTON_X_SAVE_START + 3*(CHAR_WIDTH + CHAR_SPACING); x_end <= x_start + CHAR_WIDTH - 1; y_start <= BUTTON_Y_TOP; y_end <= BUTTON_Y_TOP + CHAR_HEIGHT - 1; state <= S_TRIGGER_WAIT; end

                    // === Рамки (17-48) - 8 цифр × 4 сторони = 32 кроки ===
                    17: begin if (!edit_mode) draw_step <= 49; else begin solid_fill <= 1; solid_color <= FRAME_COLOR; x_start <= DIGIT_X_START[0]; x_end <= DIGIT_X_START[0] + DIGIT_WIDTH - 1; y_start <= FRAME_Y_TOP - FRAME_THICK; y_end <= FRAME_Y_TOP - 1; state <= S_TRIGGER_WAIT; end end
                    18: begin if (!edit_mode) draw_step <= 49; else begin solid_fill <= 1; solid_color <= FRAME_COLOR; x_start <= DIGIT_X_START[0]; x_end <= DIGIT_X_START[0] + DIGIT_WIDTH - 1; y_start <= FRAME_Y_BOTTOM; y_end <= FRAME_Y_BOTTOM + FRAME_THICK - 1; state <= S_TRIGGER_WAIT; end end
                    19: begin if (!edit_mode) draw_step <= 49; else begin solid_fill <= 1; solid_color <= FRAME_COLOR; x_start <= DIGIT_X_START[0] - FRAME_THICK; x_end <= DIGIT_X_START[0] - 1; y_start <= FRAME_Y_TOP; y_end <= FRAME_Y_BOTTOM - 1; state <= S_TRIGGER_WAIT; end end
                    20: begin if (!edit_mode) draw_step <= 49; else begin solid_fill <= 1; solid_color <= FRAME_COLOR; x_start <= DIGIT_X_START[0] + DIGIT_WIDTH; x_end <= DIGIT_X_START[0] + DIGIT_WIDTH + FRAME_THICK - 1; y_start <= FRAME_Y_TOP; y_end <= FRAME_Y_BOTTOM - 1; state <= S_TRIGGER_WAIT; end end
                    21: begin if (!edit_mode) draw_step <= 49; else begin solid_fill <= 1; solid_color <= FRAME_COLOR; x_start <= DIGIT_X_START[1]; x_end <= DIGIT_X_START[1] + DIGIT_WIDTH - 1; y_start <= FRAME_Y_TOP - FRAME_THICK; y_end <= FRAME_Y_TOP - 1; state <= S_TRIGGER_WAIT; end end
                    22: begin if (!edit_mode) draw_step <= 49; else begin solid_fill <= 1; solid_color <= FRAME_COLOR; x_start <= DIGIT_X_START[1]; x_end <= DIGIT_X_START[1] + DIGIT_WIDTH - 1; y_start <= FRAME_Y_BOTTOM; y_end <= FRAME_Y_BOTTOM + FRAME_THICK - 1; state <= S_TRIGGER_WAIT; end end
                    23: begin if (!edit_mode) draw_step <= 49; else begin solid_fill <= 1; solid_color <= FRAME_COLOR; x_start <= DIGIT_X_START[1] - FRAME_THICK; x_end <= DIGIT_X_START[1] - 1; y_start <= FRAME_Y_TOP; y_end <= FRAME_Y_BOTTOM - 1; state <= S_TRIGGER_WAIT; end end
                    24: begin if (!edit_mode) draw_step <= 49; else begin solid_fill <= 1; solid_color <= FRAME_COLOR; x_start <= DIGIT_X_START[1] + DIGIT_WIDTH; x_end <= DIGIT_X_START[1] + DIGIT_WIDTH + FRAME_THICK - 1; y_start <= FRAME_Y_TOP; y_end <= FRAME_Y_BOTTOM - 1; state <= S_TRIGGER_WAIT; end end
                    25: begin if (!edit_mode) draw_step <= 49; else begin solid_fill <= 1; solid_color <= FRAME_COLOR; x_start <= DIGIT_X_START[2]; x_end <= DIGIT_X_START[2] + DIGIT_WIDTH - 1; y_start <= FRAME_Y_TOP - FRAME_THICK; y_end <= FRAME_Y_TOP - 1; state <= S_TRIGGER_WAIT; end end
                    26: begin if (!edit_mode) draw_step <= 49; else begin solid_fill <= 1; solid_color <= FRAME_COLOR; x_start <= DIGIT_X_START[2]; x_end <= DIGIT_X_START[2] + DIGIT_WIDTH - 1; y_start <= FRAME_Y_BOTTOM; y_end <= FRAME_Y_BOTTOM + FRAME_THICK - 1; state <= S_TRIGGER_WAIT; end end
                    27: begin if (!edit_mode) draw_step <= 49; else begin solid_fill <= 1; solid_color <= FRAME_COLOR; x_start <= DIGIT_X_START[2] - FRAME_THICK; x_end <= DIGIT_X_START[2] - 1; y_start <= FRAME_Y_TOP; y_end <= FRAME_Y_BOTTOM - 1; state <= S_TRIGGER_WAIT; end end
                    28: begin if (!edit_mode) draw_step <= 49; else begin solid_fill <= 1; solid_color <= FRAME_COLOR; x_start <= DIGIT_X_START[2] + DIGIT_WIDTH; x_end <= DIGIT_X_START[2] + DIGIT_WIDTH + FRAME_THICK - 1; y_start <= FRAME_Y_TOP; y_end <= FRAME_Y_BOTTOM - 1; state <= S_TRIGGER_WAIT; end end
                    29: begin if (!edit_mode) draw_step <= 49; else begin solid_fill <= 1; solid_color <= FRAME_COLOR; x_start <= DIGIT_X_START[3]; x_end <= DIGIT_X_START[3] + DIGIT_WIDTH - 1; y_start <= FRAME_Y_TOP - FRAME_THICK; y_end <= FRAME_Y_TOP - 1; state <= S_TRIGGER_WAIT; end end
                    30: begin if (!edit_mode) draw_step <= 49; else begin solid_fill <= 1; solid_color <= FRAME_COLOR; x_start <= DIGIT_X_START[3]; x_end <= DIGIT_X_START[3] + DIGIT_WIDTH - 1; y_start <= FRAME_Y_BOTTOM; y_end <= FRAME_Y_BOTTOM + FRAME_THICK - 1; state <= S_TRIGGER_WAIT; end end
                    31: begin if (!edit_mode) draw_step <= 49; else begin solid_fill <= 1; solid_color <= FRAME_COLOR; x_start <= DIGIT_X_START[3] - FRAME_THICK; x_end <= DIGIT_X_START[3] - 1; y_start <= FRAME_Y_TOP; y_end <= FRAME_Y_BOTTOM - 1; state <= S_TRIGGER_WAIT; end end
                    32: begin if (!edit_mode) draw_step <= 49; else begin solid_fill <= 1; solid_color <= FRAME_COLOR; x_start <= DIGIT_X_START[3] + DIGIT_WIDTH; x_end <= DIGIT_X_START[3] + DIGIT_WIDTH + FRAME_THICK - 1; y_start <= FRAME_Y_TOP; y_end <= FRAME_Y_BOTTOM - 1; state <= S_TRIGGER_WAIT; end end
                    33: begin if (!edit_mode) draw_step <= 49; else begin solid_fill <= 1; solid_color <= FRAME_COLOR; x_start <= DIGIT_X_START[4]; x_end <= DIGIT_X_START[4] + DIGIT_WIDTH - 1; y_start <= FRAME_Y_TOP - FRAME_THICK; y_end <= FRAME_Y_TOP - 1; state <= S_TRIGGER_WAIT; end end
                    34: begin if (!edit_mode) draw_step <= 49; else begin solid_fill <= 1; solid_color <= FRAME_COLOR; x_start <= DIGIT_X_START[4]; x_end <= DIGIT_X_START[4] + DIGIT_WIDTH - 1; y_start <= FRAME_Y_BOTTOM; y_end <= FRAME_Y_BOTTOM + FRAME_THICK - 1; state <= S_TRIGGER_WAIT; end end
                    35: begin if (!edit_mode) draw_step <= 49; else begin solid_fill <= 1; solid_color <= FRAME_COLOR; x_start <= DIGIT_X_START[4] - FRAME_THICK; x_end <= DIGIT_X_START[4] - 1; y_start <= FRAME_Y_TOP; y_end <= FRAME_Y_BOTTOM - 1; state <= S_TRIGGER_WAIT; end end
                    36: begin if (!edit_mode) draw_step <= 49; else begin solid_fill <= 1; solid_color <= FRAME_COLOR; x_start <= DIGIT_X_START[4] + DIGIT_WIDTH; x_end <= DIGIT_X_START[4] + DIGIT_WIDTH + FRAME_THICK - 1; y_start <= FRAME_Y_TOP; y_end <= FRAME_Y_BOTTOM - 1; state <= S_TRIGGER_WAIT; end end
                    37: begin if (!edit_mode) draw_step <= 49; else begin solid_fill <= 1; solid_color <= FRAME_COLOR; x_start <= DIGIT_X_START[5]; x_end <= DIGIT_X_START[5] + DIGIT_WIDTH - 1; y_start <= FRAME_Y_TOP - FRAME_THICK; y_end <= FRAME_Y_TOP - 1; state <= S_TRIGGER_WAIT; end end
                    38: begin if (!edit_mode) draw_step <= 49; else begin solid_fill <= 1; solid_color <= FRAME_COLOR; x_start <= DIGIT_X_START[5]; x_end <= DIGIT_X_START[5] + DIGIT_WIDTH - 1; y_start <= FRAME_Y_BOTTOM; y_end <= FRAME_Y_BOTTOM + FRAME_THICK - 1; state <= S_TRIGGER_WAIT; end end
                    39: begin if (!edit_mode) draw_step <= 49; else begin solid_fill <= 1; solid_color <= FRAME_COLOR; x_start <= DIGIT_X_START[5] - FRAME_THICK; x_end <= DIGIT_X_START[5] - 1; y_start <= FRAME_Y_TOP; y_end <= FRAME_Y_BOTTOM - 1; state <= S_TRIGGER_WAIT; end end
                    40: begin if (!edit_mode) draw_step <= 49; else begin solid_fill <= 1; solid_color <= FRAME_COLOR; x_start <= DIGIT_X_START[5] + DIGIT_WIDTH; x_end <= DIGIT_X_START[5] + DIGIT_WIDTH + FRAME_THICK - 1; y_start <= FRAME_Y_TOP; y_end <= FRAME_Y_BOTTOM - 1; state <= S_TRIGGER_WAIT; end end
                    41: begin if (!edit_mode) draw_step <= 49; else begin solid_fill <= 1; solid_color <= FRAME_COLOR; x_start <= DIGIT_X_START[6]; x_end <= DIGIT_X_START[6] + DIGIT_WIDTH - 1; y_start <= FRAME_Y_TOP - FRAME_THICK; y_end <= FRAME_Y_TOP - 1; state <= S_TRIGGER_WAIT; end end
                    42: begin if (!edit_mode) draw_step <= 49; else begin solid_fill <= 1; solid_color <= FRAME_COLOR; x_start <= DIGIT_X_START[6]; x_end <= DIGIT_X_START[6] + DIGIT_WIDTH - 1; y_start <= FRAME_Y_BOTTOM; y_end <= FRAME_Y_BOTTOM + FRAME_THICK - 1; state <= S_TRIGGER_WAIT; end end
                    43: begin if (!edit_mode) draw_step <= 49; else begin solid_fill <= 1; solid_color <= FRAME_COLOR; x_start <= DIGIT_X_START[6] - FRAME_THICK; x_end <= DIGIT_X_START[6] - 1; y_start <= FRAME_Y_TOP; y_end <= FRAME_Y_BOTTOM - 1; state <= S_TRIGGER_WAIT; end end
                    44: begin if (!edit_mode) draw_step <= 49; else begin solid_fill <= 1; solid_color <= FRAME_COLOR; x_start <= DIGIT_X_START[6] + DIGIT_WIDTH; x_end <= DIGIT_X_START[6] + DIGIT_WIDTH + FRAME_THICK - 1; y_start <= FRAME_Y_TOP; y_end <= FRAME_Y_BOTTOM - 1; state <= S_TRIGGER_WAIT; end end
                    45: begin if (!edit_mode) draw_step <= 49; else begin solid_fill <= 1; solid_color <= FRAME_COLOR; x_start <= DIGIT_X_START[7]; x_end <= DIGIT_X_START[7] + DIGIT_WIDTH - 1; y_start <= FRAME_Y_TOP - FRAME_THICK; y_end <= FRAME_Y_TOP - 1; state <= S_TRIGGER_WAIT; end end
                    46: begin if (!edit_mode) draw_step <= 49; else begin solid_fill <= 1; solid_color <= FRAME_COLOR; x_start <= DIGIT_X_START[7]; x_end <= DIGIT_X_START[7] + DIGIT_WIDTH - 1; y_start <= FRAME_Y_BOTTOM; y_end <= FRAME_Y_BOTTOM + FRAME_THICK - 1; state <= S_TRIGGER_WAIT; end end
                    47: begin if (!edit_mode) draw_step <= 49; else begin solid_fill <= 1; solid_color <= FRAME_COLOR; x_start <= DIGIT_X_START[7] - FRAME_THICK; x_end <= DIGIT_X_START[7] - 1; y_start <= FRAME_Y_TOP; y_end <= FRAME_Y_BOTTOM - 1; state <= S_TRIGGER_WAIT; end end
                    48: begin if (!edit_mode) draw_step <= 49; else begin solid_fill <= 1; solid_color <= FRAME_COLOR; x_start <= DIGIT_X_START[7] + DIGIT_WIDTH; x_end <= DIGIT_X_START[7] + DIGIT_WIDTH + FRAME_THICK - 1; y_start <= FRAME_Y_TOP; y_end <= FRAME_Y_BOTTOM - 1; state <= S_TRIGGER_WAIT; end end

                    // === Стрілки (49-50) ===
                    49: begin
                        if (!edit_mode || selected_digit == 4'b1111) draw_step <= 51;
                        else begin
                            bram_base_addra <= ARROW_BASE + 0 * (ARROW_WIDTH * ARROW_HEIGHT);
                            x_start <= DIGIT_X_START[selected_digit] ;
                            x_end   <= DIGIT_X_START[selected_digit]  + ARROW_WIDTH - 1;
                            y_start <= FRAME_Y_TOP - ARROW_HEIGHT;
                            y_end   <= FRAME_Y_TOP - 1;
                            state <= S_TRIGGER_WAIT;
                        end
                    end
                    50: begin
                        if (!edit_mode || selected_digit == 4'b1111) draw_step <= 51;
                        else begin
                            bram_base_addra <= ARROW_BASE + 1 * (ARROW_WIDTH * ARROW_HEIGHT);
                            x_start <= DIGIT_X_START[selected_digit] ;
                            x_end   <= DIGIT_X_START[selected_digit]  + ARROW_WIDTH - 1;
                            y_start <= FRAME_Y_BOTTOM;
                            y_end   <= FRAME_Y_BOTTOM + ARROW_HEIGHT - 1;
                            state <= S_TRIGGER_WAIT;
                        end
                    end

                    // === Стирання старих стрілок (51-52) ===
                    51: begin
                        if (update_arrows_area) begin
                            solid_fill <= 1; solid_color <= TEXT_BACK_COLOR;
                            x_start <= DIGIT_X_START[digit_to_update] ;
                            x_end   <= DIGIT_X_START[digit_to_update]  + ARROW_WIDTH - 1;
                            y_start <= FRAME_Y_TOP - ARROW_HEIGHT;
                            y_end   <= FRAME_Y_TOP - 1;
                            state <= S_TRIGGER_WAIT;
                        end else draw_step <= 52;
                    end
                    52: begin
                        if (update_arrows_area) begin
                            solid_fill <= 1; solid_color <= TEXT_BACK_COLOR;
                            x_start <= DIGIT_X_START[digit_to_update] ;
                            x_end   <= DIGIT_X_START[digit_to_update]  + ARROW_WIDTH - 1;
                            y_start <= FRAME_Y_BOTTOM;
                            y_end   <= FRAME_Y_BOTTOM + ARROW_HEIGHT - 1;
                            state <= S_TRIGGER_WAIT;
                        end else draw_step <= 53;
                    end

                    // === Нові стрілки (53-54) ===
                    53: begin
                        if (update_arrows_area) begin
                            bram_base_addra <= ARROW_BASE + 0 * (ARROW_WIDTH * ARROW_HEIGHT);
                            x_start <= DIGIT_X_START[selected_digit] ;
                            x_end   <= DIGIT_X_START[selected_digit]  + ARROW_WIDTH - 1;
                            y_start <= FRAME_Y_TOP - ARROW_HEIGHT;
                            y_end   <= FRAME_Y_TOP - 1;
                            state <= S_TRIGGER_WAIT;
                        end else draw_step <= 54;
                    end
                    54: begin
                        if (update_arrows_area) begin
                            bram_base_addra <= ARROW_BASE + 1 * (ARROW_WIDTH * ARROW_HEIGHT);
                            x_start <= DIGIT_X_START[selected_digit] ;
                            x_end   <= DIGIT_X_START[selected_digit]  + ARROW_WIDTH - 1;
                            y_start <= FRAME_Y_BOTTOM;
                            y_end   <= FRAME_Y_BOTTOM + ARROW_HEIGHT - 1;
                            state <= S_TRIGGER_WAIT;
                        end else draw_step <= 55;
                    end

                    // === Стирання маркера (55) ===
                    55: begin
                        if (marker_erase) begin
                            solid_fill <= 1; solid_color <= MARKER_BACK;
                            x_start <= (marker_x < MARKER_SIZE/2) ? 0 : marker_x - MARKER_SIZE/2;
                            x_end   <= (marker_x + MARKER_SIZE/2 >= DISPLAY_WIDTH) ? DISPLAY_WIDTH-1 : marker_x + MARKER_SIZE/2;
                            y_start <= (marker_y < MARKER_SIZE/2) ? 0 : marker_y - MARKER_SIZE/2;
                            y_end   <= (marker_y + MARKER_SIZE/2 >= DISPLAY_HEIGH) ? DISPLAY_HEIGH-1 : marker_y + MARKER_SIZE/2;
                            state <= S_TRIGGER_WAIT;
                        end else draw_step <= 56;
                    end

                    // === Малювання маркера (56) ===
                    56: begin
                        if (update_marker) begin
                            solid_fill <= 1; solid_color <= MARKER_COLOR;
                            x_start <= (marker_x < MARKER_SIZE/2) ? 0 : marker_x - MARKER_SIZE/2;
                            x_end   <= (marker_x + MARKER_SIZE/2 >= DISPLAY_WIDTH) ? DISPLAY_WIDTH-1 : marker_x + MARKER_SIZE/2;
                            y_start <= (marker_y < MARKER_SIZE/2) ? 0 : marker_y - MARKER_SIZE/2;
                            y_end   <= (marker_y + MARKER_SIZE/2 >= DISPLAY_HEIGH) ? DISPLAY_HEIGH-1 : marker_y + MARKER_SIZE/2;
                            state <= S_TRIGGER_WAIT;
                        end else draw_step <= 62;
                    end

                    62: begin
                        draw_step <= 0;
                        state <= S_IDLE;
                    end
                    //default: draw_step <= draw_step + 1;
                endcase
            end

            S_TRIGGER_WAIT: begin
                update_screen <= 1;
                state <= S_DISPLAY;
            end

            S_DISPLAY: begin
                if (start_read_data && !solid_fill) begin
                    bram_addra <= bram_base_addra + data_count;
                end
                if (cmd_ndata_done) state <= S_DONE_DRAW;
            end

            S_DONE_DRAW: begin
                update_screen <= 0;
                draw_step <= draw_step + 1;
                state <= S_PREP_DRAW;
            end

            default: state <= S_IDLE;
        endcase
    end
end

endmodule