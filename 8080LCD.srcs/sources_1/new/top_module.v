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
reg [3:0] number [0:15];  // 16 цифр: 0-7: x_value/y_value, 8-15: screen_x/screen_y
reg need_update;
reg solid_fill;
reg [15:0] solid_color;
reg [17:0] bram_base_addra;
reg [6:0] draw_step;  // до 36
assign la_out[6:0] = draw_step[6:0];
assign la_out[7] = need_update;

reg init_fill_done;

// === Touch ===
wire [11:0] x_value, y_value;
wire get_flag;
reg touch_en;
reg [9:0] screen_x, screen_y;

// === Маркер ===
reg marker_active;
reg [9:0] marker_x, marker_y;
reg update_marker;
reg marker_erase;

// === 60 Hz ===
reg [31:0] refresh_counter;

// === BCD Conversion ===
reg [4:0] bcd_state;
reg [11:0] bcd_x, bcd_y;
reg [9:0]  bcd_screen_x, bcd_screen_y;  // для screen_x, screen_y
reg [15:0] bcd_temp;
reg [3:0] bcd_digit;
reg bcd_start;
localparam 
    BCD_IDLE        = 0,
    BCD_X_1000      = 1,
    BCD_X_1000_SUB  = 2,
    BCD_X_100       = 3,
    BCD_X_100_SUB   = 4,
    BCD_X_10        = 5,
    BCD_X_10_SUB    = 6,
    BCD_X_1         = 7,
    BCD_Y_1000      = 8,
    BCD_Y_1000_SUB  = 9,
    BCD_Y_100       = 10,
    BCD_Y_100_SUB   = 11,
    BCD_Y_10        = 12,
    BCD_Y_10_SUB    = 13,
    BCD_Y_1         = 14,
    BCD_SX_1000     = 15,
    BCD_SX_1000_SUB = 16,
    BCD_SX_100      = 17,
    BCD_SX_100_SUB  = 18,
    BCD_SX_10       = 19,
    BCD_SX_10_SUB   = 20,
    BCD_SX_1        = 21,
    BCD_SY_1000     = 22,
    BCD_SY_1000_SUB = 23,
    BCD_SY_100      = 24,
    BCD_SY_100_SUB  = 25,
    BCD_SY_10       = 26,
    BCD_SY_10_SUB   = 27,
    BCD_SY_1        = 28;

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

// === Динамічні параметри ===
localparam [11:0] TOUCH_X_MIN = `TOUCH_X_MIN;
localparam [11:0] TOUCH_X_MAX = `TOUCH_X_MAX;
localparam [11:0] TOUCH_Y_MIN = `TOUCH_Y_MIN;
localparam [11:0] TOUCH_Y_MAX = `TOUCH_Y_MAX;

localparam [15:0] DISP_W = `DISPLAY_WIDTH;
localparam [15:0] DISP_H = `DISPLAY_HEIGH;

localparam [12:0] SCALE_X = `ROTATE_90 ? `SCALE_X_ROT : `SCALE_X_NORM;
localparam [12:0] SCALE_Y = `ROTATE_90 ? `SCALE_Y_ROT : `SCALE_Y_NORM;

localparam [11:0] MAX_X_OUT = `ROTATE_90 ? 479 : 799;
localparam [11:0] MAX_Y_OUT = `ROTATE_90 ? 799 : 479;


// === Масштабування з ROTATE_90 (виправлено) ===
reg [31:0] calc_x, calc_y;
reg [9:0] temp_x;
reg [9:0] temp_y;
always @(posedge clk_main or negedge reset_n) begin
    if (!reset_n) begin
        screen_x <= 0;
        screen_y <= 0;
    end else if (get_flag) begin
        if (`ROTATE_90) begin
            // === Поворот 90° ===
            // y_value → screen_x (0-479)
            calc_y = (32'd0 + y_value - TOUCH_Y_MIN) * SCALE_Y;
            begin
                 temp_x <= calc_y[21:12];
                screen_x <= (temp_x > 479) ? 479 : temp_x;
            end

            // x_value → screen_y (0-799)
            calc_x = (32'd0 + x_value - TOUCH_X_MIN) * SCALE_X;
            begin
                 temp_y  <= calc_x[21:12];
                screen_y <= (temp_y > 799) ? 799 : temp_y;
            end

        end else begin
            // === Без повороту ===
            // x_value → screen_x (0-799)
            calc_x = (32'd0 + x_value - TOUCH_X_MIN) * SCALE_X;
            begin
                temp_x <= calc_x[21:12];
                screen_x <= (temp_x > 799) ? 799 : temp_x;
            end

            // y_value → screen_y (0-479)
            calc_y = (32'd0 + y_value - TOUCH_Y_MIN) * SCALE_Y;
            begin
                temp_y <= calc_y[21:12];
                screen_y <= (temp_y > 479) ? 479 : temp_y;
            end
        end
    end
end

// === BCD Conversion + Маркер ===
always @(posedge clk_main or negedge reset_n) begin
    if (!reset_n) begin
        for (integer i = 0; i < 16; i = i + 1) number[i] <= 0;

        marker_active <= 0;
        marker_x <= 0;
        marker_y <= 0;
        update_marker <= 0;
        marker_erase <= 0;

        bcd_state <= BCD_IDLE;
        bcd_x <= 0; bcd_y <= 0;
        bcd_screen_x <= 0; bcd_screen_y <= 0;
        bcd_temp <= 0;
        bcd_digit <= 0;
        bcd_start <= 0;
    end else begin
        update_marker <= 0;
        marker_erase <= 0;
        bcd_start <= 0;

        if (get_flag) begin
            // Запускаємо BCD для x_value, y_value, screen_x, screen_y
            bcd_x <= x_value;
            bcd_y <= y_value;
            bcd_screen_x <= screen_x;
            bcd_screen_y <= screen_y;
            bcd_state <= BCD_X_1000;
            bcd_start <= 1;

            // Маркер
            if (!marker_active || screen_x != marker_x || screen_y != marker_y) begin
                if (marker_active) marker_erase <= 1;
                marker_x <= screen_x;
                marker_y <= screen_y;
                marker_active <= 1;
                update_marker <= 1;
            end
        end else begin
            if (marker_active) begin
                marker_erase <= 1;
                marker_active <= 0;
            end
        end

        // === BCD State Machine ===
        if (bcd_start || bcd_state != BCD_IDLE) begin
            case (bcd_state)
                // === x_value ===
                BCD_X_1000: begin bcd_temp <= bcd_x; bcd_digit <= 0; bcd_state <= BCD_X_1000_SUB; end
                BCD_X_1000_SUB: begin
                    if (bcd_temp >= 1000) begin bcd_temp <= bcd_temp - 1000; bcd_digit <= bcd_digit + 1; end
                    else begin number[0] <= bcd_digit; bcd_state <= BCD_X_100; end
                end
                BCD_X_100: begin bcd_digit <= 0; bcd_state <= BCD_X_100_SUB; end
                BCD_X_100_SUB: begin
                    if (bcd_temp >= 100) begin bcd_temp <= bcd_temp - 100; bcd_digit <= bcd_digit + 1; end
                    else begin number[1] <= bcd_digit; bcd_state <= BCD_X_10; end
                end
                BCD_X_10: begin bcd_digit <= 0; bcd_state <= BCD_X_10_SUB; end
                BCD_X_10_SUB: begin
                    if (bcd_temp >= 10) begin bcd_temp <= bcd_temp - 10; bcd_digit <= bcd_digit + 1; end
                    else begin number[2] <= bcd_digit; number[3] <= bcd_temp[3:0]; bcd_state <= BCD_Y_1000; end
                end

                // === y_value ===
                BCD_Y_1000: begin bcd_temp <= bcd_y; bcd_digit <= 0; bcd_state <= BCD_Y_1000_SUB; end
                BCD_Y_1000_SUB: begin
                    if (bcd_temp >= 1000) begin bcd_temp <= bcd_temp - 1000; bcd_digit <= bcd_digit + 1; end
                    else begin number[4] <= bcd_digit; bcd_state <= BCD_Y_100; end
                end
                BCD_Y_100: begin bcd_digit <= 0; bcd_state <= BCD_Y_100_SUB; end
                BCD_Y_100_SUB: begin
                    if (bcd_temp >= 100) begin bcd_temp <= bcd_temp - 100; bcd_digit <= bcd_digit + 1; end
                    else begin number[5] <= bcd_digit; bcd_state <= BCD_Y_10; end
                end
                BCD_Y_10: begin bcd_digit <= 0; bcd_state <= BCD_Y_10_SUB; end
                BCD_Y_10_SUB: begin
                    if (bcd_temp >= 10) begin bcd_temp <= bcd_temp - 10; bcd_digit <= bcd_digit + 1; end
                    else begin number[6] <= bcd_digit; number[7] <= bcd_temp[3:0]; bcd_state <= BCD_SX_1000; end
                end

                // === screen_x ===
                BCD_SX_1000: begin bcd_temp <= {6'b0, bcd_screen_x}; bcd_digit <= 0; bcd_state <= BCD_SX_1000_SUB; end
                BCD_SX_1000_SUB: begin
                    if (bcd_temp >= 1000) begin bcd_temp <= bcd_temp - 1000; bcd_digit <= bcd_digit + 1; end
                    else begin number[8] <= bcd_digit; bcd_state <= BCD_SX_100; end
                end
                BCD_SX_100: begin bcd_digit <= 0; bcd_state <= BCD_SX_100_SUB; end
                BCD_SX_100_SUB: begin
                    if (bcd_temp >= 100) begin bcd_temp <= bcd_temp - 100; bcd_digit <= bcd_digit + 1; end
                    else begin number[9] <= bcd_digit; bcd_state <= BCD_SX_10; end
                end
                BCD_SX_10: begin bcd_digit <= 0; bcd_state <= BCD_SX_10_SUB; end
                BCD_SX_10_SUB: begin
                    if (bcd_temp >= 10) begin bcd_temp <= bcd_temp - 10; bcd_digit <= bcd_digit + 1; end
                    else begin number[10] <= bcd_digit; number[11] <= bcd_temp[3:0]; bcd_state <= BCD_SY_1000; end
                end

                // === screen_y ===
                BCD_SY_1000: begin bcd_temp <= {6'b0, bcd_screen_y}; bcd_digit <= 0; bcd_state <= BCD_SY_1000_SUB; end
                BCD_SY_1000_SUB: begin
                    if (bcd_temp >= 1000) begin bcd_temp <= bcd_temp - 1000; bcd_digit <= bcd_digit + 1; end
                    else begin number[12] <= bcd_digit; bcd_state <= BCD_SY_100; end
                end
                BCD_SY_100: begin bcd_digit <= 0; bcd_state <= BCD_SY_100_SUB; end
                BCD_SY_100_SUB: begin
                    if (bcd_temp >= 100) begin bcd_temp <= bcd_temp - 100; bcd_digit <= bcd_digit + 1; end
                    else begin number[13] <= bcd_digit; bcd_state <= BCD_SY_10; end
                end
                BCD_SY_10: begin bcd_digit <= 0; bcd_state <= BCD_SY_10_SUB; end
                BCD_SY_10_SUB: begin
                    if (bcd_temp >= 10) begin bcd_temp <= bcd_temp - 10; bcd_digit <= bcd_digit + 1; end
                    else begin number[14] <= bcd_digit; number[15] <= bcd_temp[3:0]; bcd_state <= BCD_IDLE; end
                end

                default: bcd_state <= BCD_IDLE;
            endcase
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
                if (draw_step == 36) need_update <= 0;  // 16 цифр + маркер
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
        x_start <= 0; x_end <= `DISPLAY_WIDTH - 1;
        y_start <= 0; y_end <= `DISPLAY_HEIGH - 1;
        draw_step <= 0;
        solid_fill <= 0;
        init_fill_done <= 0;
    end else begin

        case (state)
            S_INIT: begin
                if (init_done && !init_fill_done) begin
                    solid_fill <= 1;
                    solid_color <= TEXT_BACK_COLOR;
                    x_start <= 0; x_end <= `DISPLAY_WIDTH - 1;
                    y_start <= 0; y_end <= `DISPLAY_HEIGH - 1;
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

// === 8 цифр ===
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
                        
                        
                    // === 8 цифр ===
                    9: begin bram_base_addra <= number[8] * (DIGIT_WIDTH * DIGIT_HEIGHT);
                        x_start <= DIGIT_X_START[0]; x_end <= DIGIT_X_START[0] + DIGIT_WIDTH - 1;
                        y_start <= DIGIT_Y + DIGIT_HEIGHT; y_end <= DIGIT_Y + 2 * DIGIT_HEIGHT - 1; state <= S_TRIGGER_WAIT; end
                    10: begin bram_base_addra <= number[9] * (DIGIT_WIDTH * DIGIT_HEIGHT);
                        x_start <= DIGIT_X_START[1]; x_end <= DIGIT_X_START[1] + DIGIT_WIDTH - 1;
                        y_start <= DIGIT_Y + DIGIT_HEIGHT; y_end <= DIGIT_Y + 2 * DIGIT_HEIGHT - 1; state <= S_TRIGGER_WAIT; end
                    11: begin bram_base_addra <= number[10] * (DIGIT_WIDTH * DIGIT_HEIGHT);
                        x_start <= DIGIT_X_START[2]; x_end <= DIGIT_X_START[2] + DIGIT_WIDTH - 1;
                        y_start <= DIGIT_Y + DIGIT_HEIGHT; y_end <= DIGIT_Y + 2 * DIGIT_HEIGHT - 1; state <= S_TRIGGER_WAIT; end
                    12: begin bram_base_addra <= number[11] * (DIGIT_WIDTH * DIGIT_HEIGHT);
                        x_start <= DIGIT_X_START[3]; x_end <= DIGIT_X_START[3] + DIGIT_WIDTH - 1;
                        y_start <= DIGIT_Y + DIGIT_HEIGHT; y_end <= DIGIT_Y + 2 * DIGIT_HEIGHT - 1; state <= S_TRIGGER_WAIT; end
                    13: begin bram_base_addra <= number[12] * (DIGIT_WIDTH * DIGIT_HEIGHT);
                        x_start <= DIGIT_X_START[4]; x_end <= DIGIT_X_START[4] + DIGIT_WIDTH - 1;
                        y_start <= DIGIT_Y + DIGIT_HEIGHT; y_end <= DIGIT_Y + 2 * DIGIT_HEIGHT - 1; state <= S_TRIGGER_WAIT; end
                    14: begin bram_base_addra <= number[13] * (DIGIT_WIDTH * DIGIT_HEIGHT);
                        x_start <= DIGIT_X_START[5]; x_end <= DIGIT_X_START[5] + DIGIT_WIDTH - 1;
                        y_start <= DIGIT_Y + DIGIT_HEIGHT; y_end <= DIGIT_Y + 2 * DIGIT_HEIGHT - 1; state <= S_TRIGGER_WAIT; end
                    15: begin bram_base_addra <= number[14] * (DIGIT_WIDTH * DIGIT_HEIGHT);
                        x_start <= DIGIT_X_START[6]; x_end <= DIGIT_X_START[6] + DIGIT_WIDTH - 1;
                        y_start <= DIGIT_Y + DIGIT_HEIGHT; y_end <= DIGIT_Y + 2 * DIGIT_HEIGHT - 1; state <= S_TRIGGER_WAIT; end
                    16: begin bram_base_addra <= number[15] * (DIGIT_WIDTH * DIGIT_HEIGHT);
                        x_start <= DIGIT_X_START[7]; x_end <= DIGIT_X_START[7] + DIGIT_WIDTH - 1;
                        y_start <= DIGIT_Y + DIGIT_HEIGHT; y_end <= DIGIT_Y + 2 * DIGIT_HEIGHT - 1; state <= S_TRIGGER_WAIT; end
                            

                    // === Стирання маркера ===
                    17: begin
                        if (marker_erase) begin
                            solid_fill <= 1; solid_color <= MARKER_BACK;
x_start <= (marker_x < MARKER_SIZE/2) ? 0 : marker_x - MARKER_SIZE/2;
x_end   <= (marker_x + MARKER_SIZE/2 >= DISP_W) ? DISP_W-1 : marker_x + MARKER_SIZE/2;
y_start <= (marker_y < MARKER_SIZE/2) ? 0 : marker_y - MARKER_SIZE/2;
y_end   <= (marker_y + MARKER_SIZE/2 >= DISP_H) ? DISP_H-1 : marker_y + MARKER_SIZE/2;
                            state <= S_TRIGGER_WAIT;
                        end else draw_step <= 18;
                    end

                    // === Малювання маркера ===
                    18: begin
                        if (update_marker) begin
                            solid_fill <= 1; solid_color <= MARKER_COLOR;
x_start <= (marker_x < MARKER_SIZE/2) ? 0 : marker_x - MARKER_SIZE/2;
x_end   <= (marker_x + MARKER_SIZE/2 >= DISP_W) ? DISP_W-1 : marker_x + MARKER_SIZE/2;
y_start <= (marker_y < MARKER_SIZE/2) ? 0 : marker_y - MARKER_SIZE/2;
y_end   <= (marker_y + MARKER_SIZE/2 >= DISP_H) ? DISP_H-1 : marker_y + MARKER_SIZE/2;
                            state <= S_TRIGGER_WAIT;
                        end else draw_step <= 36;
                    end

                    36: begin
                        draw_step <= 0;
                        state <= S_IDLE;
                    end
                    default: draw_step <= draw_step + 1;
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