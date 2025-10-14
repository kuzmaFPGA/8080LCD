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
    // Сигнали для XPT2046
    output        ts_clk,        // SPI такт (DCLK)
    output        ts_cs,         // SPI Chip Select (CS_N)
    input         ts_miso,       // SPI MISO (DOUT)
    output        ts_mosi,       // SPI MOSI (DIN)
    input         ts_pen         // Сигнал переривання від XPT2046
);

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
// Сигнали для XPT2046
wire [11:0] x_value, y_value;
wire get_flag;
reg  touch_en;

// Сигнали для BRAM
wire bram_douta;
reg [17:0] bram_addra;

wire clk_main;

clk_wiz_1 main_clk_pll (
    .clk_in1(clk),
    .resetn(reset_n),
    .clk_out1(clk_main)
);

localparam S_INIT = 0, S_IDLE = 1, S_PREP_DRAW = 2, S_TRIGGER_WAIT = 3, S_DISPLAY = 4, S_DONE_DRAW = 5;

// Additional regs for new functionality
reg edit_mode = 0;
reg [2:0] selected_digit = 3'b111; // 111 means none selected
reg [3:0] number [0:4];
initial begin
    number[0] = 0;
    number[1] = 0;
    number[2] = 0;
    number[3] = 0;
    number[4] = 0;
end
reg need_update = 1;
reg solid_fill;
reg [15:0] solid_color;
reg [17:0] bram_base_addra;
reg [5:0] draw_step; // Up to 36 steps

// Touch processing
reg [9:0] screen_x;
reg [10:0] screen_y;
reg touch_valid;

// Assume mapping (adjust calibration if needed)
always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        screen_x <= 0;
        screen_y <= 0;
        touch_valid <= 0;
    end else if (get_flag) begin
        screen_x <= (4095 - y_value) * DISPLAY_HEIGH >> 12; // Map to 480x800 display
        screen_y <= x_value * DISPLAY_WIDTH >> 12;
        touch_valid <= 1;
    end else begin
        touch_valid <= 0;
    end
end

// Touch handling logic (generates combinational need_update_request)
reg need_update_request;
always @(*) begin
    need_update_request = 0; // Default: no update needed
    if (touch_valid) begin
        if (edit_mode) begin
            // Check arrows if a digit is selected
            if (selected_digit != 3'b111) begin
                if (screen_x >= (DIGIT_X_START + selected_digit * DIGIT_SPACING + ARROW_X_OFFSET) && 
                    screen_x < (DIGIT_X_START + selected_digit * DIGIT_SPACING + ARROW_X_OFFSET + ARROW_WIDTH) &&
                    screen_y >= (FRAME_Y_TOP - ARROW_Y_OFFSET) && screen_y < FRAME_Y_TOP) begin // Up arrow
                    need_update_request = 1;
                end else if (screen_x >= (DIGIT_X_START + selected_digit * DIGIT_SPACING + ARROW_X_OFFSET) && 
                             screen_x < (DIGIT_X_START + selected_digit * DIGIT_SPACING + ARROW_X_OFFSET + ARROW_WIDTH) &&
                             screen_y >= FRAME_Y_BOTTOM && screen_y < (FRAME_Y_BOTTOM + ARROW_Y_OFFSET)) begin // Down arrow
                    need_update_request = 1;
                end
            end
            // Check digit positions
            if (screen_x >= DIGIT_X_START && screen_x < (DIGIT_X_START + DIGIT_WIDTH) && 
                screen_y >= FRAME_Y_TOP && screen_y < FRAME_Y_BOTTOM) begin // Digit 0
                need_update_request = 1;
            end else if (screen_x >= (DIGIT_X_START + DIGIT_SPACING) && screen_x < (DIGIT_X_START + DIGIT_SPACING + DIGIT_WIDTH) && 
                         screen_y >= FRAME_Y_TOP && screen_y < FRAME_Y_BOTTOM) begin // Digit 1
                need_update_request = 1;
            end else if (screen_x >= (DIGIT_X_START + 2 * DIGIT_SPACING) && screen_x < (DIGIT_X_START + 2 * DIGIT_SPACING + DIGIT_WIDTH) && 
                         screen_y >= FRAME_Y_TOP && screen_y < FRAME_Y_BOTTOM) begin // Digit 2
                need_update_request = 1;
            end else if (screen_x >= (DIGIT_X_START + 3 * DIGIT_SPACING) && screen_x < (DIGIT_X_START + 3 * DIGIT_SPACING + DIGIT_WIDTH) && 
                         screen_y >= FRAME_Y_TOP && screen_y < FRAME_Y_BOTTOM) begin // Digit 3
                need_update_request = 1;
            end else if (screen_x >= (DIGIT_X_START + 4 * DIGIT_SPACING) && screen_x < (DIGIT_X_START + 4 * DIGIT_SPACING + DIGIT_WIDTH) && 
                         screen_y >= FRAME_Y_TOP && screen_y < FRAME_Y_BOTTOM) begin // Digit 4
                need_update_request = 1;
            end
        end else begin
            // Check buttons
            if (screen_x >= BUTTON_X_EDIT_START && screen_x < BUTTON_X_EDIT_END && 
                screen_y >= BUTTON_Y_TOP && screen_y < BUTTON_Y_BOTTOM) begin // Edit button
                need_update_request = 1;
            end else if (screen_x >= BUTTON_X_SAVE_START && screen_x < BUTTON_X_SAVE_END && 
                         screen_y >= BUTTON_Y_TOP && screen_y < BUTTON_Y_BOTTOM) begin // Save button
                need_update_request = 1;
            end
        end
    end
end

// Consolidated need_update and touch state updates
always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        edit_mode <= 0;
        selected_digit <= 3'b111;
        need_update <= 1; // Initial draw on reset
        number[0] <= 0;
        number[1] <= 0;
        number[2] <= 0;
        number[3] <= 0;
        number[4] <= 0;
    end else begin
        // Update need_update based on request or FSM clear
        if (need_update_request) begin
            need_update <= 1;
        end
        // Update touch-related states
        if (touch_valid) begin
            if (edit_mode) begin
                // Check arrows if a digit is selected
                if (selected_digit != 3'b111) begin
                    if (screen_x >= (DIGIT_X_START + selected_digit * DIGIT_SPACING + ARROW_X_OFFSET) && 
                        screen_x < (DIGIT_X_START + selected_digit * DIGIT_SPACING + ARROW_X_OFFSET + ARROW_WIDTH) &&
                        screen_y >= (FRAME_Y_TOP - ARROW_Y_OFFSET) && screen_y < FRAME_Y_TOP) begin // Up arrow
                        number[selected_digit] <= (number[selected_digit] == 9) ? 0 : number[selected_digit] + 1;
                    end else if (screen_x >= (DIGIT_X_START + selected_digit * DIGIT_SPACING + ARROW_X_OFFSET) && 
                                 screen_x < (DIGIT_X_START + selected_digit * DIGIT_SPACING + ARROW_X_OFFSET + ARROW_WIDTH) &&
                                 screen_y >= FRAME_Y_BOTTOM && screen_y < (FRAME_Y_BOTTOM + ARROW_Y_OFFSET)) begin // Down arrow
                        number[selected_digit] <= (number[selected_digit] == 0) ? 9 : number[selected_digit] - 1;
                    end
                end
                // Check digit positions
                if (screen_x >= DIGIT_X_START && screen_x < (DIGIT_X_START + DIGIT_WIDTH) && 
                    screen_y >= FRAME_Y_TOP && screen_y < FRAME_Y_BOTTOM) begin // Digit 0
                    selected_digit <= 0;
                end else if (screen_x >= (DIGIT_X_START + DIGIT_SPACING) && screen_x < (DIGIT_X_START + DIGIT_SPACING + DIGIT_WIDTH) && 
                             screen_y >= FRAME_Y_TOP && screen_y < FRAME_Y_BOTTOM) begin // Digit 1
                    selected_digit <= 1;
                end else if (screen_x >= (DIGIT_X_START + 2 * DIGIT_SPACING) && screen_x < (DIGIT_X_START + 2 * DIGIT_SPACING + DIGIT_WIDTH) && 
                             screen_y >= FRAME_Y_TOP && screen_y < FRAME_Y_BOTTOM) begin // Digit 2
                    selected_digit <= 2;
                end else if (screen_x >= (DIGIT_X_START + 3 * DIGIT_SPACING) && screen_x < (DIGIT_X_START + 3 * DIGIT_SPACING + DIGIT_WIDTH) && 
                             screen_y >= FRAME_Y_TOP && screen_y < FRAME_Y_BOTTOM) begin // Digit 3
                    selected_digit <= 3;
                end else if (screen_x >= (DIGIT_X_START + 4 * DIGIT_SPACING) && screen_x < (DIGIT_X_START + 4 * DIGIT_SPACING + DIGIT_WIDTH) && 
                             screen_y >= FRAME_Y_TOP && screen_y < FRAME_Y_BOTTOM) begin // Digit 4
                    selected_digit <= 4;
                end
            end else begin
                // Check buttons
                if (screen_x >= BUTTON_X_EDIT_START && screen_x < BUTTON_X_EDIT_END && 
                    screen_y >= BUTTON_Y_TOP && screen_y < BUTTON_Y_BOTTOM) begin // Edit button
                    edit_mode <= 1;
                end else if (screen_x >= BUTTON_X_SAVE_START && screen_x < BUTTON_X_SAVE_END && 
                             screen_y >= BUTTON_Y_TOP && screen_y < BUTTON_Y_BOTTOM) begin // Save button
                    edit_mode <= 0;
                    selected_digit <= 3'b111; // Clear selection
                end
            end
        end
    end
end

// BRAM
blk_mem_gen_0 bram (
    .clka(clk),    // input wire clka
    .addra(bram_addra),  // input wire [17 : 0] addra
    .douta(bram_douta)  // output wire [0 : 0] douta
);

// LCD instance
lcd lcd_inst (
    .clk(clk),
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

// XPT2046 instance
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

// Touch screen enable
always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        touch_en <= 1'b0;
    end else begin
        touch_en <= 1'b1;
    end
end

// Pixel data assignment
assign pixel_data = solid_fill ? solid_color : (bram_douta ? TEXT_COLOR : TEXT_BACK_COLOR);

// FSM for drawing (only clears need_update)
always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        bram_addra <= 0;
        state <= S_INIT;
        update_screen <= 0;
        x_start <= 0;
        x_end <= TEXT_WIDTH - 1;
        y_start <= 0;
        y_end <= TEXT_HEIGH - 1;
        delay_counter <= 0;
        draw_step <= 0;
        solid_fill <= 0;
        need_update <= 1; // Initial draw on reset
    end else begin
        case (state)
            S_INIT: begin
                if (init_done) begin
                    state <= S_IDLE;
                end
            end    
            S_IDLE: begin
                if (need_update) begin
                    need_update <= 0; // Clear need_update (single driver in FSM)
                    draw_step <= 0;
                    state <= S_PREP_DRAW;
                end
            end
            S_PREP_DRAW: begin
                solid_fill <= 0;
                update_screen <= 0;
                case (draw_step)
                    0: begin // Clear screen
                        solid_fill <= 1;
                        solid_color <= WHITE;
                        x_start <= 0;
                        x_end <= DISPLAY_WIDTH - 1;
                        y_start <= 0;
                        y_end <= DISPLAY_HEIGH - 1;
                        state <= S_TRIGGER_WAIT;
                    end
                    1: begin // Digit 0
                        bram_base_addra <= number[0] * (DIGIT_WIDTH * DIGIT_HEIGHT);
                        x_start <= DIGIT_X_START;
                        x_end <= DIGIT_X_START + DIGIT_WIDTH - 1;
                        y_start <= DIGIT_Y;
                        y_end <= DIGIT_Y + DIGIT_HEIGHT - 1;
                        state <= S_TRIGGER_WAIT;
                    end
                    2: begin // Digit 1
                        bram_base_addra <= number[1] * (DIGIT_WIDTH * DIGIT_HEIGHT);
                        x_start <= DIGIT_X_START + DIGIT_SPACING;
                        x_end <= DIGIT_X_START + DIGIT_SPACING + DIGIT_WIDTH - 1;
                        y_start <= DIGIT_Y;
                        y_end <= DIGIT_Y + DIGIT_HEIGHT - 1;
                        state <= S_TRIGGER_WAIT;
                    end
                    3: begin // Digit 2
                        bram_base_addra <= number[2] * (DIGIT_WIDTH * DIGIT_HEIGHT);
                        x_start <= DIGIT_X_START + 2 * DIGIT_SPACING;
                        x_end <= DIGIT_X_START + 2 * DIGIT_SPACING + DIGIT_WIDTH - 1;
                        y_start <= DIGIT_Y;
                        y_end <= DIGIT_Y + DIGIT_HEIGHT - 1;
                        state <= S_TRIGGER_WAIT;
                    end
                    4: begin // Digit 3
                        bram_base_addra <= number[3] * (DIGIT_WIDTH * DIGIT_HEIGHT);
                        x_start <= DIGIT_X_START + 3 * DIGIT_SPACING;
                        x_end <= DIGIT_X_START + 3 * DIGIT_SPACING + DIGIT_WIDTH - 1;
                        y_start <= DIGIT_Y;
                        y_end <= DIGIT_Y + DIGIT_HEIGHT - 1;
                        state <= S_TRIGGER_WAIT;
                    end
                    5: begin // Digit 4
                        bram_base_addra <= number[4] * (DIGIT_WIDTH * DIGIT_HEIGHT);
                        x_start <= DIGIT_X_START + 4 * DIGIT_SPACING;
                        x_end <= DIGIT_X_START + 4 * DIGIT_SPACING + DIGIT_WIDTH - 1;
                        y_start <= DIGIT_Y;
                        y_end <= DIGIT_Y + DIGIT_HEIGHT - 1;
                        state <= S_TRIGGER_WAIT;
                    end
                    6: begin // Edit 'E'
                        bram_base_addra <= CHAR_BASE + 0 * (CHAR_WIDTH * CHAR_HEIGHT);
                        x_start <= EDIT_X;
                        x_end <= EDIT_X + CHAR_WIDTH - 1;
                        y_start <= BUTTON_Y;
                        y_end <= BUTTON_Y + CHAR_HEIGHT - 1;
                        state <= S_TRIGGER_WAIT;
                    end
                    7: begin // 'd'
                        bram_base_addra <= CHAR_BASE + 1 * (CHAR_WIDTH * CHAR_HEIGHT);
                        x_start <= EDIT_X + CHAR_SPACING;
                        x_end <= EDIT_X + CHAR_SPACING + CHAR_WIDTH - 1;
                        y_start <= BUTTON_Y;
                        y_end <= BUTTON_Y + CHAR_HEIGHT - 1;
                        state <= S_TRIGGER_WAIT;
                    end
                    8: begin // 'i'
                        bram_base_addra <= CHAR_BASE + 2 * (CHAR_WIDTH * CHAR_HEIGHT);
                        x_start <= EDIT_X + 2 * CHAR_SPACING;
                        x_end <= EDIT_X + 2 * CHAR_SPACING + CHAR_WIDTH - 1;
                        y_start <= BUTTON_Y;
                        y_end <= BUTTON_Y + CHAR_HEIGHT - 1;
                        state <= S_TRIGGER_WAIT;
                    end
                    9: begin // 't'
                        bram_base_addra <= CHAR_BASE + 3 * (CHAR_WIDTH * CHAR_HEIGHT);
                        x_start <= EDIT_X + 3 * CHAR_SPACING;
                        x_end <= EDIT_X + 3 * CHAR_SPACING + CHAR_WIDTH - 1;
                        y_start <= BUTTON_Y;
                        y_end <= BUTTON_Y + CHAR_HEIGHT - 1;
                        state <= S_TRIGGER_WAIT;
                    end
                    10: begin // Save 'S'
                        bram_base_addra <= CHAR_BASE + 4 * (CHAR_WIDTH * CHAR_HEIGHT);
                        x_start <= SAVE_X;
                        x_end <= SAVE_X + CHAR_WIDTH - 1;
                        y_start <= BUTTON_Y;
                        y_end <= BUTTON_Y + CHAR_HEIGHT - 1;
                        state <= S_TRIGGER_WAIT;
                    end
                    11: begin // 'a'
                        bram_base_addra <= CHAR_BASE + 5 * (CHAR_WIDTH * CHAR_HEIGHT);
                        x_start <= SAVE_X + CHAR_SPACING;
                        x_end <= SAVE_X + CHAR_SPACING + CHAR_WIDTH - 1;
                        y_start <= BUTTON_Y;
                        y_end <= BUTTON_Y + CHAR_HEIGHT - 1;
                        state <= S_TRIGGER_WAIT;
                    end
                    12: begin // 'v'
                        bram_base_addra <= CHAR_BASE + 6 * (CHAR_WIDTH * CHAR_HEIGHT);
                        x_start <= SAVE_X + 2 * CHAR_SPACING;
                        x_end <= SAVE_X + 2 * CHAR_SPACING + CHAR_WIDTH - 1;
                        y_start <= BUTTON_Y;
                        y_end <= BUTTON_Y + CHAR_HEIGHT - 1;
                        state <= S_TRIGGER_WAIT;
                    end
                    13: begin // 'e'
                        bram_base_addra <= CHAR_BASE + 7 * (CHAR_WIDTH * CHAR_HEIGHT);
                        x_start <= SAVE_X + 3 * CHAR_SPACING;
                        x_end <= SAVE_X + 3 * CHAR_SPACING + CHAR_WIDTH - 1;
                        y_start <= BUTTON_Y;
                        y_end <= BUTTON_Y + CHAR_HEIGHT - 1;
                        state <= S_TRIGGER_WAIT;
                    end
                    // Frames (14-33: 5 digits * 4 lines)
                    14: begin
                        if (!edit_mode) draw_step <= draw_step + 1;
                        else begin
                            solid_fill <= 1;
                            solid_color <= RED;
                            x_start <= DIGIT_X_START;
                            x_end <= DIGIT_X_START + DIGIT_WIDTH - 1;
                            y_start <= FRAME_Y_TOP - FRAME_THICK;
                            y_end <= FRAME_Y_TOP - 1;
                            state <= S_TRIGGER_WAIT;
                        end
                    end
                    15: begin
                        if (!edit_mode) draw_step <= draw_step + 1;
                        else begin
                            solid_fill <= 1;
                            solid_color <= RED;
                            x_start <= DIGIT_X_START;
                            x_end <= DIGIT_X_START + DIGIT_WIDTH - 1;
                            y_start <= FRAME_Y_BOTTOM;
                            y_end <= FRAME_Y_BOTTOM + FRAME_THICK - 1;
                            state <= S_TRIGGER_WAIT;
                        end
                    end
                    16: begin
                        if (!edit_mode) draw_step <= draw_step + 1;
                        else begin
                            solid_fill <= 1;
                            solid_color <= RED;
                            x_start <= DIGIT_X_START - FRAME_THICK;
                            x_end <= DIGIT_X_START - 1;
                            y_start <= FRAME_Y_TOP;
                            y_end <= FRAME_Y_BOTTOM - 1;
                            state <= S_TRIGGER_WAIT;
                        end
                    end
                    17: begin
                        if (!edit_mode) draw_step <= draw_step + 1;
                        else begin
                            solid_fill <= 1;
                            solid_color <= RED;
                            x_start <= DIGIT_X_START + DIGIT_WIDTH;
                            x_end <= DIGIT_X_START + DIGIT_WIDTH + FRAME_THICK - 1;
                            y_start <= FRAME_Y_TOP;
                            y_end <= FRAME_Y_BOTTOM - 1;
                            state <= S_TRIGGER_WAIT;
                        end
                    end
                    // Frames for digit 1 (18-21)
                    18: begin
                        if (!edit_mode) draw_step <= draw_step + 1;
                        else begin
                            solid_fill <= 1;
                            solid_color <= RED;
                            x_start <= DIGIT_X_START + DIGIT_SPACING;
                            x_end <= DIGIT_X_START + DIGIT_SPACING + DIGIT_WIDTH - 1;
                            y_start <= FRAME_Y_TOP - FRAME_THICK;
                            y_end <= FRAME_Y_TOP - 1;
                            state <= S_TRIGGER_WAIT;
                        end
                    end
                    19: begin
                        if (!edit_mode) draw_step <= draw_step + 1;
                        else begin
                            solid_fill <= 1;
                            solid_color <= RED;
                            x_start <= DIGIT_X_START + DIGIT_SPACING;
                            x_end <= DIGIT_X_START + DIGIT_SPACING + DIGIT_WIDTH - 1;
                            y_start <= FRAME_Y_BOTTOM;
                            y_end <= FRAME_Y_BOTTOM + FRAME_THICK - 1;
                            state <= S_TRIGGER_WAIT;
                        end
                    end
                    20: begin
                        if (!edit_mode) draw_step <= draw_step + 1;
                        else begin
                            solid_fill <= 1;
                            solid_color <= RED;
                            x_start <= DIGIT_X_START + DIGIT_SPACING - FRAME_THICK;
                            x_end <= DIGIT_X_START + DIGIT_SPACING - 1;
                            y_start <= FRAME_Y_TOP;
                            y_end <= FRAME_Y_BOTTOM - 1;
                            state <= S_TRIGGER_WAIT;
                        end
                    end
                    21: begin
                        if (!edit_mode) draw_step <= draw_step + 1;
                        else begin
                            solid_fill <= 1;
                            solid_color <= RED;
                            x_start <= DIGIT_X_START + DIGIT_SPACING + DIGIT_WIDTH;
                            x_end <= DIGIT_X_START + DIGIT_SPACING + DIGIT_WIDTH + FRAME_THICK - 1;
                            y_start <= FRAME_Y_TOP;
                            y_end <= FRAME_Y_BOTTOM - 1;
                            state <= S_TRIGGER_WAIT;
                        end
                    end
                    // Frames for digit 2 (22-25)
                    22: begin
                        if (!edit_mode) draw_step <= draw_step + 1;
                        else begin
                            solid_fill <= 1;
                            solid_color <= RED;
                            x_start <= DIGIT_X_START + 2 * DIGIT_SPACING;
                            x_end <= DIGIT_X_START + 2 * DIGIT_SPACING + DIGIT_WIDTH - 1;
                            y_start <= FRAME_Y_TOP - FRAME_THICK;
                            y_end <= FRAME_Y_TOP - 1;
                            state <= S_TRIGGER_WAIT;
                        end
                    end
                    23: begin
                        if (!edit_mode) draw_step <= draw_step + 1;
                        else begin
                            solid_fill <= 1;
                            solid_color <= RED;
                            x_start <= DIGIT_X_START + 2 * DIGIT_SPACING;
                            x_end <= DIGIT_X_START + 2 * DIGIT_SPACING + DIGIT_WIDTH - 1;
                            y_start <= FRAME_Y_BOTTOM;
                            y_end <= FRAME_Y_BOTTOM + FRAME_THICK - 1;
                            state <= S_TRIGGER_WAIT;
                        end
                    end
                    24: begin
                        if (!edit_mode) draw_step <= draw_step + 1;
                        else begin
                            solid_fill <= 1;
                            solid_color <= RED;
                            x_start <= DIGIT_X_START + 2 * DIGIT_SPACING - FRAME_THICK;
                            x_end <= DIGIT_X_START + 2 * DIGIT_SPACING - 1;
                            y_start <= FRAME_Y_TOP;
                            y_end <= FRAME_Y_BOTTOM - 1;
                            state <= S_TRIGGER_WAIT;
                        end
                    end
                    25: begin
                        if (!edit_mode) draw_step <= draw_step + 1;
                        else begin
                            solid_fill <= 1;
                            solid_color <= RED;
                            x_start <= DIGIT_X_START + 2 * DIGIT_SPACING + DIGIT_WIDTH;
                            x_end <= DIGIT_X_START + 2 * DIGIT_SPACING + DIGIT_WIDTH + FRAME_THICK - 1;
                            y_start <= FRAME_Y_TOP;
                            y_end <= FRAME_Y_BOTTOM - 1;
                            state <= S_TRIGGER_WAIT;
                        end
                    end
                    // Frames for digit 3 (26-29)
                    26: begin
                        if (!edit_mode) draw_step <= draw_step + 1;
                        else begin
                            solid_fill <= 1;
                            solid_color <= RED;
                            x_start <= DIGIT_X_START + 3 * DIGIT_SPACING;
                            x_end <= DIGIT_X_START + 3 * DIGIT_SPACING + DIGIT_WIDTH - 1;
                            y_start <= FRAME_Y_TOP - FRAME_THICK;
                            y_end <= FRAME_Y_TOP - 1;
                            state <= S_TRIGGER_WAIT;
                        end
                    end
                    27: begin
                        if (!edit_mode) draw_step <= draw_step + 1;
                        else begin
                            solid_fill <= 1;
                            solid_color <= RED;
                            x_start <= DIGIT_X_START + 3 * DIGIT_SPACING;
                            x_end <= DIGIT_X_START + 3 * DIGIT_SPACING + DIGIT_WIDTH - 1;
                            y_start <= FRAME_Y_BOTTOM;
                            y_end <= FRAME_Y_BOTTOM + FRAME_THICK - 1;
                            state <= S_TRIGGER_WAIT;
                        end
                    end
                    28: begin
                        if (!edit_mode) draw_step <= draw_step + 1;
                        else begin
                            solid_fill <= 1;
                            solid_color <= RED;
                            x_start <= DIGIT_X_START + 3 * DIGIT_SPACING - FRAME_THICK;
                            x_end <= DIGIT_X_START + 3 * DIGIT_SPACING - 1;
                            y_start <= FRAME_Y_TOP;
                            y_end <= FRAME_Y_BOTTOM - 1;
                            state <= S_TRIGGER_WAIT;
                        end
                    end
                    29: begin
                        if (!edit_mode) draw_step <= draw_step + 1;
                        else begin
                            solid_fill <= 1;
                            solid_color <= RED;
                            x_start <= DIGIT_X_START + 3 * DIGIT_SPACING + DIGIT_WIDTH;
                            x_end <= DIGIT_X_START + 3 * DIGIT_SPACING + DIGIT_WIDTH + FRAME_THICK - 1;
                            y_start <= FRAME_Y_TOP;
                            y_end <= FRAME_Y_BOTTOM - 1;
                            state <= S_TRIGGER_WAIT;
                        end
                    end
                    // Frames for digit 4 (30-33)
                    30: begin
                        if (!edit_mode) draw_step <= draw_step + 1;
                        else begin
                            solid_fill <= 1;
                            solid_color <= RED;
                            x_start <= DIGIT_X_START + 4 * DIGIT_SPACING;
                            x_end <= DIGIT_X_START + 4 * DIGIT_SPACING + DIGIT_WIDTH - 1;
                            y_start <= FRAME_Y_TOP - FRAME_THICK;
                            y_end <= FRAME_Y_TOP - 1;
                            state <= S_TRIGGER_WAIT;
                        end
                    end
                    31: begin
                        if (!edit_mode) draw_step <= draw_step + 1;
                        else begin
                            solid_fill <= 1;
                            solid_color <= RED;
                            x_start <= DIGIT_X_START + 4 * DIGIT_SPACING;
                            x_end <= DIGIT_X_START + 4 * DIGIT_SPACING + DIGIT_WIDTH - 1;
                            y_start <= FRAME_Y_BOTTOM;
                            y_end <= FRAME_Y_BOTTOM + FRAME_THICK - 1;
                            state <= S_TRIGGER_WAIT;
                        end
                    end
                    32: begin
                        if (!edit_mode) draw_step <= draw_step + 1;
                        else begin
                            solid_fill <= 1;
                            solid_color <= RED;
                            x_start <= DIGIT_X_START + 4 * DIGIT_SPACING - FRAME_THICK;
                            x_end <= DIGIT_X_START + 4 * DIGIT_SPACING - 1;
                            y_start <= FRAME_Y_TOP;
                            y_end <= FRAME_Y_BOTTOM - 1;
                            state <= S_TRIGGER_WAIT;
                        end
                    end
                    33: begin
                        if (!edit_mode) draw_step <= draw_step + 1;
                        else begin
                            solid_fill <= 1;
                            solid_color <= RED;
                            x_start <= DIGIT_X_START + 4 * DIGIT_SPACING + DIGIT_WIDTH;
                            x_end <= DIGIT_X_START + 4 * DIGIT_SPACING + DIGIT_WIDTH + FRAME_THICK - 1;
                            y_start <= FRAME_Y_TOP;
                            y_end <= FRAME_Y_BOTTOM - 1;
                            state <= S_TRIGGER_WAIT;
                        end
                    end
                    34: begin // Up arrow
                        if (selected_digit == 3'b111) draw_step <= draw_step + 1;
                        else begin
                            bram_base_addra <= ARROW_BASE + 0 * (ARROW_WIDTH * ARROW_HEIGHT);
                            x_start <= DIGIT_X_START + selected_digit * DIGIT_SPACING + ARROW_X_OFFSET;
                            x_end <= DIGIT_X_START + selected_digit * DIGIT_SPACING + ARROW_X_OFFSET + ARROW_WIDTH - 1;
                            y_start <= FRAME_Y_TOP - ARROW_HEIGHT;
                            y_end <= FRAME_Y_TOP - 1;
                            state <= S_TRIGGER_WAIT;
                        end
                    end
                    35: begin // Down arrow
                        if (selected_digit == 3'b111) draw_step <= draw_step + 1;
                        else begin
                            bram_base_addra <= ARROW_BASE + 1 * (ARROW_WIDTH * ARROW_HEIGHT);
                            x_start <= DIGIT_X_START + selected_digit * DIGIT_SPACING + ARROW_X_OFFSET;
                            x_end <= DIGIT_X_START + selected_digit * DIGIT_SPACING + ARROW_X_OFFSET + ARROW_WIDTH - 1;
                            y_start <= FRAME_Y_BOTTOM;
                            y_end <= FRAME_Y_BOTTOM + ARROW_HEIGHT - 1;
                            state <= S_TRIGGER_WAIT;
                        end
                    end
                    default: begin
                        state <= S_IDLE;
                    end
                endcase
                if (draw_step >= 36) state <= S_IDLE;
            end
            S_TRIGGER_WAIT: begin
                update_screen <= 1;
                state <= S_DISPLAY;
            end
            S_DISPLAY: begin
                if (start_read_data) begin
                    if (!solid_fill) bram_addra <= bram_base_addra + data_count;
                end
                if (cmd_ndata_done) begin
                    state <= S_DONE_DRAW;
                end
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