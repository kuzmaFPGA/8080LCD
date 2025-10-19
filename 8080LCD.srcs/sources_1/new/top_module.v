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
    input         ts_pen,         // Сигнал переривання від XPT2046
    output        led_1
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
reg [2:0] selected_digit = 3'b111; // 111 means none selected
reg [3:0] number [0:4];
initial begin
    number[0] = 0; number[1] = 1; number[2] = 2; number[3] = 3; number[4] = 4;
end
reg need_update = 1;
reg solid_fill;
reg [15:0] solid_color;
reg [17:0] bram_base_addra;
reg [5:0] draw_step; // Up to 36 steps

// ✅ Touch processing
wire [11:0] x_value, y_value;
wire get_flag;
reg touch_en;
reg [9:0] screen_x;   // 0-799
reg [9:0] screen_y;   // 0-479
reg touch_valid;

// ✅ Touch mapping для 800x480
always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        screen_x <= 0;
        screen_y <= 0;
        touch_valid <= 0;
    end else if (get_flag) begin
        screen_x <= ((4095 - y_value) * DISPLAY_WIDTH >> 12) ^ ({12{`INVERT_X}} & 4095);  // Інверсія X, якщо `INVERT_X` = 1
        screen_y <= (x_value * DISPLAY_HEIGH >> 12) ^ ({12{`INVERT_Y}} & 4095);          // Інверсія Y, якщо `INVERT_Y` = 1
        touch_valid <= 1;
    end else begin
        touch_valid <= 0;
    end
end

// ✅ Touch handling logic
reg need_update_request;
always @(*) begin
    need_update_request = 0;
    if (touch_valid) begin
        if (edit_mode) begin
            // Arrows if digit selected
            if (selected_digit != 3'b111) begin
                // Up arrow
                if (screen_x >= (DIGIT_X_START[selected_digit] - 31) && 
                    screen_x < (DIGIT_X_START[selected_digit] - 31 + ARROW_WIDTH) &&
                    screen_y >= (FRAME_Y_TOP - ARROW_HEIGHT) && 
                    screen_y < FRAME_Y_TOP) begin
                    need_update_request = 1;
				end
                // Down arrow
                else if (screen_x >= (DIGIT_X_START[selected_digit] - 31) && 
					screen_x < (DIGIT_X_START[selected_digit] - 31 + ARROW_WIDTH) &&
					screen_y >= FRAME_Y_BOTTOM && 
					screen_y < (FRAME_Y_BOTTOM + ARROW_HEIGHT)) begin
                    need_update_request = 1;
				end
			end
            // Digit selection
            for (int i = 0; i < 5; i++) begin
                if (screen_x >= DIGIT_X_START[i] && screen_x < (DIGIT_X_START[i] + DIGIT_WIDTH) && 
                    screen_y >= FRAME_Y_TOP && screen_y < FRAME_Y_BOTTOM) begin
                    need_update_request = 1;
				end
			end
			end else begin
            // Buttons
            if (screen_x >= BUTTON_X_EDIT_START && screen_x < BUTTON_X_EDIT_END && 
                screen_y >= BUTTON_Y_TOP && screen_y < BUTTON_Y_BOTTOM) begin
                need_update_request = 1;
				end else if (screen_x >= BUTTON_X_SAVE_START && screen_x < BUTTON_X_SAVE_END && 
				screen_y >= BUTTON_Y_TOP && screen_y < BUTTON_Y_BOTTOM) begin
                need_update_request = 1;
			end
		end
	end
end

// ✅ Main state update
always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        edit_mode <= 0;
        selected_digit <= 3'b111;
        need_update <= 1;
        number[0] <= 0; number[1] <= 1; number[2] <= 2; number[3] <= 3; number[4] <= 4;
		end else begin
        if (need_update_request) need_update <= 1;
        
        if (touch_valid) begin
            if (edit_mode) begin
                // Arrows
                if (selected_digit != 3'b111) begin
                    // Up arrow
                    if (screen_x >= (DIGIT_X_START[selected_digit] - 31) && 
                        screen_x < (DIGIT_X_START[selected_digit] - 31 + ARROW_WIDTH) &&
                        screen_y >= (FRAME_Y_TOP - ARROW_HEIGHT) && 
                        screen_y < FRAME_Y_TOP) begin
                        number[selected_digit] <= (number[selected_digit] == 9) ? 0 : number[selected_digit] + 1;
					end
                    // Down arrow
                    else if (screen_x >= (DIGIT_X_START[selected_digit] - 31) && 
						screen_x < (DIGIT_X_START[selected_digit] - 31 + ARROW_WIDTH) &&
						screen_y >= FRAME_Y_BOTTOM && 
						screen_y < (FRAME_Y_BOTTOM + ARROW_HEIGHT)) begin
                        number[selected_digit] <= (number[selected_digit] == 0) ? 9 : number[selected_digit] - 1;
					end
				end
                // Digit selection
                if (screen_x >= DIGIT_X_START[0] && screen_x < (DIGIT_X_START[0] + DIGIT_WIDTH) && 
				screen_y >= FRAME_Y_TOP && screen_y < FRAME_Y_BOTTOM) selected_digit <= 0;
                else if (screen_x >= DIGIT_X_START[1] && screen_x < (DIGIT_X_START[1] + DIGIT_WIDTH) && 
				screen_y >= FRAME_Y_TOP && screen_y < FRAME_Y_BOTTOM) selected_digit <= 1;
                else if (screen_x >= DIGIT_X_START[2] && screen_x < (DIGIT_X_START[2] + DIGIT_WIDTH) && 
				screen_y >= FRAME_Y_TOP && screen_y < FRAME_Y_BOTTOM) selected_digit <= 2;
                else if (screen_x >= DIGIT_X_START[3] && screen_x < (DIGIT_X_START[3] + DIGIT_WIDTH) && 
				screen_y >= FRAME_Y_TOP && screen_y < FRAME_Y_BOTTOM) selected_digit <= 3;
                else if (screen_x >= DIGIT_X_START[4] && screen_x < (DIGIT_X_START[4] + DIGIT_WIDTH) && 
				screen_y >= FRAME_Y_TOP && screen_y < FRAME_Y_BOTTOM) selected_digit <= 4;
				end else begin
                // Buttons
                if (screen_x >= BUTTON_X_EDIT_START && screen_x < BUTTON_X_EDIT_END && 
                    screen_y >= BUTTON_Y_TOP && screen_y < BUTTON_Y_BOTTOM) begin
                    edit_mode <= 1;
					end else if (screen_x >= BUTTON_X_SAVE_START && screen_x < BUTTON_X_SAVE_END && 
					screen_y >= BUTTON_Y_TOP && screen_y < BUTTON_Y_BOTTOM) begin
                    edit_mode <= 0;
                    selected_digit <= 3'b111;
				end
			end
		end
	end
end

// ✅ NEW: Блок для оновлення екрану 60 Гц
reg [31:0] refresh_counter;
always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        refresh_counter <= 0;
        need_update <= 1; // Початкове оновлення
		end else begin
        if (refresh_counter >= SCREEN_REFRESH_TICKS - 1) begin
            refresh_counter <= 0;
            need_update <= 1; // Тригер оновлення кожні 16.67 мс
            led_1_reg <= ~led_1_reg;
			end else begin
            refresh_counter <= refresh_counter + 1;
		end
	end
end

// ✅ BRAM
blk_mem_gen_0 bram (
    .clka(clk),
    .addra(bram_addra),
    .douta(bram_douta)
);

// ✅ LCD instance
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

// ✅ XPT2046 instance
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

// ✅ Touch enable
always @(posedge clk or negedge reset_n) begin
    if (!reset_n) touch_en <= 1'b0;
    else touch_en <= 1'b1;
end

// ✅ Pixel data
assign pixel_data = solid_fill ? solid_color : (bram_douta ? TEXT_COLOR : TEXT_BACK_COLOR);

// ✅ MAIN FSM (36 steps)
always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        bram_addra <= 0;
        state <= S_INIT;
        update_screen <= 0;
        x_start <= 0; x_end <= DISPLAY_WIDTH - 1;
        y_start <= 0; y_end <= DISPLAY_HEIGH - 1;
        delay_counter <= 0;
        draw_step <= 0;
        solid_fill <= 0;
        need_update <= 1;
		end else begin
        case (state)
            S_INIT: if (init_done) state <= S_IDLE;
            S_IDLE: if (need_update) begin
                need_update <= 0;
                draw_step <= 0;
                state <= S_PREP_DRAW;
			end
			S_PREP_DRAW: begin
				solid_fill <= 0;
				update_screen <= 0;
				case (draw_step)
					// 0: Clear screen
					0: begin
						solid_fill <= 1; solid_color <= TEXT_BACK_COLOR;
						x_start <= 0; x_end <= DISPLAY_WIDTH - 1;
						y_start <= 0; y_end <= DISPLAY_HEIGH - 1;
						state <= S_TRIGGER_WAIT;
					end
					// 1-5: Digits (64×128) - ЗавЖДИ
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
					// 6-9: EDIT button (78×128) - ЗавЖДИ
					
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
					// 10-13: SAVE button (78×128) - ЗавЖДИ
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
					// ✅ 14-33: FRAMES (5 digits × 4 lines) - ТІЛЬКИ в Edit mode!
					14: begin
						if (!edit_mode) draw_step <= 36; // Пропустити рамки
						else begin // Рама 0 верх
							solid_fill <= 1; solid_color <= FRAME_COLOR;
							x_start <= DIGIT_X_START[0]; x_end <= DIGIT_X_START[0] + DIGIT_WIDTH - 1;
							y_start <= FRAME_Y_TOP - FRAME_THICK; y_end <= FRAME_Y_TOP - 1; state <= S_TRIGGER_WAIT;
						end
					end
					15: begin if (!edit_mode) draw_step <= 36;
						else begin // Рама 0 низ
							solid_fill <= 1; solid_color <= FRAME_COLOR;
							x_start <= DIGIT_X_START[0]; x_end <= DIGIT_X_START[0] + DIGIT_WIDTH - 1;
							y_start <= FRAME_Y_BOTTOM; y_end <= FRAME_Y_BOTTOM + FRAME_THICK - 1; state <= S_TRIGGER_WAIT;
						end
					end
					16: begin if (!edit_mode) draw_step <= 36;
						else begin // Рама 0 ліва
							solid_fill <= 1; solid_color <= FRAME_COLOR;
							x_start <= DIGIT_X_START[0] - FRAME_THICK; x_end <= DIGIT_X_START[0] - 1;
							y_start <= FRAME_Y_TOP; y_end <= FRAME_Y_BOTTOM - 1; state <= S_TRIGGER_WAIT;
						end
					end
					17: begin if (!edit_mode) draw_step <= 36;
						else begin // Рама 0 права
							solid_fill <= 1; solid_color <= FRAME_COLOR;
							x_start <= DIGIT_X_START[0] + DIGIT_WIDTH; x_end <= DIGIT_X_START[0] + DIGIT_WIDTH + FRAME_THICK - 1;
							y_start <= FRAME_Y_TOP; y_end <= FRAME_Y_BOTTOM - 1; state <= S_TRIGGER_WAIT;
						end
					end
					18: begin if (!edit_mode) draw_step <= 36;
						else begin // Рама 1 верх
							solid_fill <= 1; solid_color <= FRAME_COLOR;
							x_start <= DIGIT_X_START[1]; x_end <= DIGIT_X_START[1] + DIGIT_WIDTH - 1;
							y_start <= FRAME_Y_TOP - FRAME_THICK; y_end <= FRAME_Y_TOP - 1; state <= S_TRIGGER_WAIT;
						end
					end
					19: begin if (!edit_mode) draw_step <= 36;
						else begin // Рама 1 низ
							solid_fill <= 1; solid_color <= FRAME_COLOR;
							x_start <= DIGIT_X_START[1]; x_end <= DIGIT_X_START[1] + DIGIT_WIDTH - 1;
							y_start <= FRAME_Y_BOTTOM; y_end <= FRAME_Y_BOTTOM + FRAME_THICK - 1; state <= S_TRIGGER_WAIT;
						end
					end
					20: begin if (!edit_mode) draw_step <= 36;
						else begin // Рама 1 ліва
							solid_fill <= 1; solid_color <= FRAME_COLOR;
							x_start <= DIGIT_X_START[1] - FRAME_THICK; x_end <= DIGIT_X_START[1] - 1;
							y_start <= FRAME_Y_TOP; y_end <= FRAME_Y_BOTTOM - 1; state <= S_TRIGGER_WAIT;
						end
					end
					21: begin if (!edit_mode) draw_step <= 36;
						else begin // Рама 1 права
							solid_fill <= 1; solid_color <= FRAME_COLOR;
							x_start <= DIGIT_X_START[1] + DIGIT_WIDTH; x_end <= DIGIT_X_START[1] + DIGIT_WIDTH + FRAME_THICK - 1;
							y_start <= FRAME_Y_TOP; y_end <= FRAME_Y_BOTTOM - 1; state <= S_TRIGGER_WAIT;
						end
					end
					22: begin if (!edit_mode) draw_step <= 36;
						else begin // Рама 2 верх
							solid_fill <= 1; solid_color <= FRAME_COLOR;
							x_start <= DIGIT_X_START[2]; x_end <= DIGIT_X_START[2] + DIGIT_WIDTH - 1;
							y_start <= FRAME_Y_TOP - FRAME_THICK; y_end <= FRAME_Y_TOP - 1; state <= S_TRIGGER_WAIT;
						end
					end
					23: begin if (!edit_mode) draw_step <= 36;
						else begin // Рама 2 низ
							solid_fill <= 1; solid_color <= FRAME_COLOR;
							x_start <= DIGIT_X_START[2]; x_end <= DIGIT_X_START[2] + DIGIT_WIDTH - 1;
							y_start <= FRAME_Y_BOTTOM; y_end <= FRAME_Y_BOTTOM + FRAME_THICK - 1; state <= S_TRIGGER_WAIT;
						end
					end
					24: begin if (!edit_mode) draw_step <= 36;
						else begin // Рама 2 ліва
							solid_fill <= 1; solid_color <= FRAME_COLOR;
							x_start <= DIGIT_X_START[2] - FRAME_THICK; x_end <= DIGIT_X_START[2] - 1;
							y_start <= FRAME_Y_TOP; y_end <= FRAME_Y_BOTTOM - 1; state <= S_TRIGGER_WAIT;
						end
					end
					25: begin if (!edit_mode) draw_step <= 36;
						else begin // Рама 2 права
							solid_fill <= 1; solid_color <= FRAME_COLOR;
							x_start <= DIGIT_X_START[2] + DIGIT_WIDTH; x_end <= DIGIT_X_START[2] + DIGIT_WIDTH + FRAME_THICK - 1;
							y_start <= FRAME_Y_TOP; y_end <= FRAME_Y_BOTTOM - 1; state <= S_TRIGGER_WAIT;
						end
					end
					26: begin if (!edit_mode) draw_step <= 36;
						else begin // Рама 3 верх
							solid_fill <= 1; solid_color <= FRAME_COLOR;
							x_start <= DIGIT_X_START[3]; x_end <= DIGIT_X_START[3] + DIGIT_WIDTH - 1;
							y_start <= FRAME_Y_TOP - FRAME_THICK; y_end <= FRAME_Y_TOP - 1; state <= S_TRIGGER_WAIT;
						end
					end
					27: begin if (!edit_mode) draw_step <= 36;
						else begin // Рама 3 низ
							solid_fill <= 1; solid_color <= FRAME_COLOR;
							x_start <= DIGIT_X_START[3]; x_end <= DIGIT_X_START[3] + DIGIT_WIDTH - 1;
							y_start <= FRAME_Y_BOTTOM; y_end <= FRAME_Y_BOTTOM + FRAME_THICK - 1; state <= S_TRIGGER_WAIT;
						end
					end
					28: begin if (!edit_mode) draw_step <= 36;
						else begin // Рама 3 ліва
							solid_fill <= 1; solid_color <= FRAME_COLOR;
							x_start <= DIGIT_X_START[3] - FRAME_THICK; x_end <= DIGIT_X_START[3] - 1;
							y_start <= FRAME_Y_TOP; y_end <= FRAME_Y_BOTTOM - 1; state <= S_TRIGGER_WAIT;
						end
					end
					29: begin if (!edit_mode) draw_step <= 36;
						else begin // Рама 3 права
							solid_fill <= 1; solid_color <= FRAME_COLOR;
							x_start <= DIGIT_X_START[3] + DIGIT_WIDTH; x_end <= DIGIT_X_START[3] + DIGIT_WIDTH + FRAME_THICK - 1;
							y_start <= FRAME_Y_TOP; y_end <= FRAME_Y_BOTTOM - 1; state <= S_TRIGGER_WAIT;
						end
					end
					30: begin if (!edit_mode) draw_step <= 36;
						else begin // Рама 4 верх
							solid_fill <= 1; solid_color <= FRAME_COLOR;
							x_start <= DIGIT_X_START[4]; x_end <= DIGIT_X_START[4] + DIGIT_WIDTH - 1;
							y_start <= FRAME_Y_TOP - FRAME_THICK; y_end <= FRAME_Y_TOP - 1; state <= S_TRIGGER_WAIT;
						end
					end
					31: begin if (!edit_mode) draw_step <= 36;
						else begin // Рама 4 низ
							solid_fill <= 1; solid_color <= FRAME_COLOR;
							x_start <= DIGIT_X_START[4]; x_end <= DIGIT_X_START[4] + DIGIT_WIDTH - 1;
							y_start <= FRAME_Y_BOTTOM; y_end <= FRAME_Y_BOTTOM + FRAME_THICK - 1; state <= S_TRIGGER_WAIT;
						end
					end
					32: begin if (!edit_mode) draw_step <= 36;
						else begin // Рама 4 ліва
							solid_fill <= 1; solid_color <= FRAME_COLOR;
							x_start <= DIGIT_X_START[4] - FRAME_THICK; x_end <= DIGIT_X_START[4] - 1;
							y_start <= FRAME_Y_TOP; y_end <= FRAME_Y_BOTTOM - 1; state <= S_TRIGGER_WAIT;
						end
					end
					33: begin if (!edit_mode) draw_step <= 36;
						else begin // Рама 4 права
							solid_fill <= 1; solid_color <= FRAME_COLOR;
							x_start <= DIGIT_X_START[4] + DIGIT_WIDTH; x_end <= DIGIT_X_START[4] + DIGIT_WIDTH + FRAME_THICK - 1;
							y_start <= FRAME_Y_TOP; y_end <= FRAME_Y_BOTTOM - 1; state <= S_TRIGGER_WAIT;
						end
					end
					
					// ✅ 34-35: Arrows  - ТІЛЬКИ в Edit mode + вибрана цифра!
					34: begin
						if (!edit_mode || selected_digit == 3'b111) draw_step <= 36; // Пропустити стрілки
						else begin // Up arrow
							bram_base_addra <= ARROW_BASE + 0 * (ARROW_WIDTH * ARROW_HEIGHT);
							x_start <= DIGIT_X_START[selected_digit]; 
							x_end <= DIGIT_X_START[selected_digit] + ARROW_WIDTH;
							y_start <= FRAME_Y_TOP - ARROW_HEIGHT; 
							y_end <= FRAME_Y_TOP - 1; 
							state <= S_TRIGGER_WAIT;
						end
					end
					35: begin
						if (!edit_mode || selected_digit == 3'b111) draw_step <= 36; // Пропустити стрілки
						else begin // Down arrow
							bram_base_addra <= ARROW_BASE + 1 * (ARROW_WIDTH * ARROW_HEIGHT);
							x_start <= DIGIT_X_START[selected_digit]; 
							x_end <= DIGIT_X_START[selected_digit] + ARROW_WIDTH;
							y_start <= FRAME_Y_BOTTOM + 1; 
							y_end <= FRAME_Y_BOTTOM + ARROW_HEIGHT; 
							state <= S_TRIGGER_WAIT;
						end
					end
					default: state <= S_IDLE;
				endcase
				
                if (edit_mode) begin
                    if (draw_step >= 36) state <= S_IDLE; // Edit: 36 кроків
					end else begin
                    if (draw_step >= 14) state <= S_IDLE; // Normal: 14 кроків
				end			
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