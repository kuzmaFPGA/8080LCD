`include "constants.vh"

// ============================================================
// top_level - 8-цифровий редактор частоти + ШИМ + DDS до ЦАП
//
// Клавіатура 4x4:
//   0-9 - записати цифру в позицію курсора, курсор → вправо
//   A   - курсор вліво
//   B   - курсор вправо
//   C   - очистити поточне поле (основне чи ШИМ - за курсором)
//   D   - курсор на початок поточного поля
//   #   - перемкнути тип сигналу (sine→square→triangle→pwm→…)
//
// Позиції курсора:
//   0..7  - основне число (частота в Гц)
//   8..11 - число ШИМ (доступно тільки в режимі PWM)
//
// Логіка прихованих нулів для основного числа:
//   - ведучі нулі замінюються пробілом
//   - цифра під курсором завжди видима
//   - якщо всі нулі - показуємо останній "0"
//   - для ШИМ цифр ведучі нулі не приховуються (формат XX.XX)
// ============================================================

module top_level (
    input         clk,
    input         reset_n,
    input  [3:0]  row_data_in,
    output [3:0]  col_data_out,
    // LCD
    output [15:0] LCD_DATA,
    output        LCD_WR,
    output        LCD_RS,
    output        LCD_CS,
    output        LCD_RESET,
    output        LCD_BL,
    output        LCD_RDX,
    // LED
    output        led_1,
    // Touch (не використовується)
    output        ts_clk,
    output        ts_cs,
    input         ts_miso,
    output        ts_mosi,
    input         ts_pen,
    // SDRAM (не використовується)
    output        SDRAM_CKE,
    output        SDRAM_WEn,
    output        SDRAM_CASn,
    output        SDRAM_RASn,
    output reg [12:0] SDRAM_A,
    output reg [1:0]  SDRAM_BA,
    output reg [1:0]  SDRAM_DQM,
    inout  [15:0] SDRAM_DQ,
    // DAC 14-біт @ 165 МГц
    output [13:0] DAC_DATA,
    output        DAC_CLK,
    output        DAC_CLK_TEST  // clk_dac / 100 для тестування
);

// ────────────────────────────────────────────────────────────
// Константи відображення
// ────────────────────────────────────────────────────────────
localparam DIGIT_COUNT  = 8;
localparam PWM_COUNT    = 4;
localparam DIGIT_W      = TEXT_WIDTH;    // 64 px
localparam DIGIT_H      = TEXT_HEIGH;    // 128 px

// Основне число - рядок вгорі
localparam MAIN_Y       = 16'd100;
localparam MAIN_X0      = 16'd0;

// ШИМ число - рядок нижче (XX.XX), 4 цифри + точка
localparam PWM_Y        = 16'd260;
localparam PWM_X0       = 16'd160;       // центрування 4 цифр + точки
localparam DOT_W        = 16'd16;        // ширина прямокутника під точку
localparam DOT_SIZE     = 16'd16;        // висота точки

// Колір курсора
localparam CURSOR_COLOR = 16'h07E0;      // зелений
localparam CURSOR_H     = 16'd8;
localparam BG_COLOR     = WHITE;
localparam FG_COLOR     = RED;

// Типи сигналу
localparam WAVE_SINE     = 2'd0,
           WAVE_SQUARE   = 2'd1,
           WAVE_TRIANGLE = 2'd2,
           WAVE_PWM      = 2'd3;

// Кроки малювання:
//   1..8   - 8 цифр основного числа
//   9..16  - курсорні смужки під основними цифрами
//   17..20 - 4 цифри ШИМ
//   21..24 - курсорні смужки під ШИМ
//   25     - десяткова точка між pwm_digit[1] і pwm_digit[2]
//   26     - кінець
localparam STEP_FIRST = 1;
localparam STEP_LAST  = 27;

// Кольори індикатора режиму (RGB565)
localparam MODE_COLOR_SINE     = 16'h07FF;  // блакитний
localparam MODE_COLOR_SQUARE   = 16'hFFE0;  // жовтий
localparam MODE_COLOR_TRIANGLE = 16'hF81F;  // пурпуровий
localparam MODE_COLOR_PWM      = 16'hFD20;  // оранжевий

// Координати індикатора режиму (лівий верхній кут)
localparam MODE_X0 = 16'd10;
localparam MODE_X1 = 16'd109;   // 100 px ширина
localparam MODE_Y0 = 16'd10;
localparam MODE_Y1 = 16'd89;    // 80 px висота

// ────────────────────────────────────────────────────────────
// Тактові сигнали
// ────────────────────────────────────────────────────────────
// Єдиний PLL з трьома виходами:
//   clk_out1 - 50 МГц  (sys_clk: і для LCD, і для логіки top_module)
//   clk_out2 - 165 МГц (clk_dac)
//   clk_out3 - 5 МГц   (kbd_clk: повільний для надійного антидребезгу)
wire sys_clk, clk_dac, kbd_clk;
wire pll_locked;
clk_wiz_1 main_clk_pll (
    .clk_in1 (clk),
    .resetn  (reset_n),
    .clk_out1(sys_clk),
    .clk_out2(clk_dac),
    .clk_out3(kbd_clk),
    .locked  (pll_locked)
);
// Аліаси (для зворотної сумісності з рештою коду)
wire clk_main = sys_clk;
wire lcd_clk  = sys_clk;

// ────────────────────────────────────────────────────────────
// LCD сигнали
// ────────────────────────────────────────────────────────────
wire [15:0] pixel_data;
reg         update_screen;
wire        init_done;
wire [31:0] data_count;
wire        start_read_data;
wire        cmd_done;
wire        cmd_data_done;
wire        cmd_ndata_done;
wire [4:0]  lcd_state;
reg  [15:0] x_start, x_end, y_start, y_end;

// ────────────────────────────────────────────────────────────
// BRAM
// ────────────────────────────────────────────────────────────
wire        bram_douta;
reg  [17:0] bram_addra;
reg  [17:0] bram_base_addra;
reg         solid_fill;
reg  [15:0] solid_color;

assign pixel_data = solid_fill   ? solid_color :
                    drawing_icon ? (icon_pixel ? 16'hFFFF : mode_bg_color) :
                                   (bram_douta ? FG_COLOR  : BG_COLOR);

// ────────────────────────────────────────────────────────────
// Стан редактора
// ────────────────────────────────────────────────────────────
reg [3:0] digit     [0:DIGIT_COUNT-1]; // основне число (видимі цифри)
reg [3:0] pwm_digit [0:PWM_COUNT-1];   // ШИМ XX.XX
reg [3:0] cursor_pos;                  // 0..7 (main) або 8..11 (PWM)
reg [1:0] wave_type;
reg       insert_mode;                  // 1 = INSERT (зсув), 0 = REPLACE
// Резерв цифр для кожного типу сигналу: {wave_type, position} → digit
// При # зберігаємо поточні цифри під wave_type і завантажуємо для wave_type_next
reg [3:0] digit_backup [0:31];          // 4 режими × 8 цифр
reg       cursor_hidden;                // 1 = курсор схований після Enter

// Допоміжні сигнали
wire cursor_in_pwm = (cursor_pos >= 4'd8);
wire [3:0] max_cursor = (wave_type == WAVE_PWM) ? 4'd11 : 4'd7;
// Мінімальна позиція для поточного поля:
//   PWM            → 8
//   INSERT в main  → 7  (курсор завжди на правому краю)
//   REPLACE в main → 0
wire [3:0] field_min = cursor_in_pwm     ? 4'd8 :
                       insert_mode       ? 4'd7 :
                                           4'd0;

// ────────────────────────────────────────────────────────────
// LED - блимає після init_done
// ────────────────────────────────────────────────────────────
reg        led_1_reg;
assign     led_1 = led_1_reg;
reg [31:0] led_counter;
always @(posedge clk_main or negedge reset_n) begin
    if (!reset_n) begin
        led_counter <= 0;
        led_1_reg   <= 0;
    end else if (init_done) begin
        if (led_counter >= MAIN_CLK_FREQ_KHZ * 500 - 1) begin
            led_counter <= 0;
            led_1_reg   <= ~led_1_reg;
        end else
            led_counter <= led_counter + 1;
    end
end

// ────────────────────────────────────────────────────────────
// Клавіатура - kbd_clk = 5 МГц з PLL.
// LFSR25000 проектувався під ~25 МГц; на нижчій частоті інтервали між
// пробами колонок більші, антидребезг працює надійніше.
// ────────────────────────────────────────────────────────────
wire       key_ready;
wire [3:0] key_data_out;
wire [3:0] press_count;
reg        key_read;
reg        key_prev_ready;
reg        need_redraw_clk;

KeyPadInterpreter keypad_inst (
    .Clock      (kbd_clk),
    .ResetButton(reset_n),
    .KeyRead    (key_read),
    .RowDataIn  (row_data_in),
    .KeyReady   (key_ready),
    .DataOut    (key_data_out),
    .ColDataOut (col_data_out),
    .PressCount (press_count)
);

// ────────────────────────────────────────────────────────────
// Перевірка ліміту частоти (для main-поля)
// Ліміт залежить від типу сигналу - current_max_freq:
//   SINE / SQUARE / TRIANGLE / PWM мають різні якісні максимуми.
// PWM-поле (4 цифри XX.XX) не перевіряється.
// ────────────────────────────────────────────────────────────
wire [26:0] current_max_freq =
    (wave_type == WAVE_SINE)     ? MAX_FREQ_SINE_HZ     :
    (wave_type == WAVE_SQUARE)   ? MAX_FREQ_SQUARE_HZ   :
    (wave_type == WAVE_TRIANGLE) ? MAX_FREQ_TRIANGLE_HZ :
                                   MAX_FREQ_PWM_HZ;

wire [1:0] wave_type_next = wave_type + 2'd1;
wire [26:0] next_max_freq =
    (wave_type_next == WAVE_SINE)     ? MAX_FREQ_SINE_HZ     :
    (wave_type_next == WAVE_SQUARE)   ? MAX_FREQ_SQUARE_HZ   :
    (wave_type_next == WAVE_TRIANGLE) ? MAX_FREQ_TRIANGLE_HZ :
                                        MAX_FREQ_PWM_HZ;

// Поточне значення freq з kbd_clk domain (для перевірки при #)
wire [26:0] freq_hz_kbd =
    digit[0] * 27'd10_000_000 +
    digit[1] * 27'd1_000_000  +
    digit[2] * 27'd100_000    +
    digit[3] * 27'd10_000     +
    digit[4] * 27'd1_000      +
    digit[5] * 27'd100        +
    digit[6] * 27'd10         +
    digit[7];

// ────────────────────────────────────────────────────────────
wire [29:0] candidate_insert =
    digit[1] * 30'd10_000_000 +
    digit[2] * 30'd1_000_000  +
    digit[3] * 30'd100_000    +
    digit[4] * 30'd10_000     +
    digit[5] * 30'd1_000      +
    digit[6] * 30'd100        +
    digit[7] * 30'd10         +
    {26'd0, key_data_out};

wire [3:0] hyp_d0 = (cursor_pos == 4'd0) ? key_data_out : digit[0];
wire [3:0] hyp_d1 = (cursor_pos == 4'd1) ? key_data_out : digit[1];
wire [3:0] hyp_d2 = (cursor_pos == 4'd2) ? key_data_out : digit[2];
wire [3:0] hyp_d3 = (cursor_pos == 4'd3) ? key_data_out : digit[3];
wire [3:0] hyp_d4 = (cursor_pos == 4'd4) ? key_data_out : digit[4];
wire [3:0] hyp_d5 = (cursor_pos == 4'd5) ? key_data_out : digit[5];
wire [3:0] hyp_d6 = (cursor_pos == 4'd6) ? key_data_out : digit[6];
wire [3:0] hyp_d7 = (cursor_pos == 4'd7) ? key_data_out : digit[7];

wire [29:0] candidate_replace =
    hyp_d0 * 30'd10_000_000 +
    hyp_d1 * 30'd1_000_000  +
    hyp_d2 * 30'd100_000    +
    hyp_d3 * 30'd10_000     +
    hyp_d4 * 30'd1_000      +
    hyp_d5 * 30'd100        +
    hyp_d6 * 30'd10         +
    {26'd0, hyp_d7};

wire candidate_ok_insert  = (candidate_insert  <= {3'd0, current_max_freq});
wire candidate_ok_replace = (candidate_replace <= {3'd0, current_max_freq});

integer ki;
always @(posedge kbd_clk or negedge reset_n) begin
    if (!reset_n) begin
        key_read        <= 0;
        key_prev_ready  <= 0;
        need_redraw_clk <= 0;
        cursor_pos      <= 4'd7;        // праворуч у main (для INSERT)
        wave_type       <= WAVE_SINE;
        insert_mode     <= 1'b1;        // за замовчуванням - INSERT
        for (ki = 0; ki < DIGIT_COUNT; ki = ki + 1) digit[ki]        <= 0;
        for (ki = 0; ki < PWM_COUNT;   ki = ki + 1) pwm_digit[ki]    <= 0;
        for (ki = 0; ki < 32;          ki = ki + 1) digit_backup[ki] <= 0;
        cursor_hidden   <= 1'b0;
    end else begin
        key_read        <= 0;
        need_redraw_clk <= 0;
        key_prev_ready  <= key_ready;

        if (key_ready && !key_prev_ready) begin
            key_read <= 1;

            case (key_data_out)
                // ── Цифри 0-9 ────────────────────────────────
                4'h0, 4'h1, 4'h2, 4'h3, 4'h4,
                4'h5, 4'h6, 4'h7, 4'h8, 4'h9: begin
                    cursor_hidden <= 1'b0;
                    if (cursor_in_pwm) begin
                        // PWM завжди в режимі REPLACE (4 цифри XX.XX без ліміту)
                        pwm_digit[cursor_pos - 4'd8] <= key_data_out;
                        if (cursor_pos < max_cursor)
                            cursor_pos <= cursor_pos + 4'd1;
                        need_redraw_clk <= 1;
                    end else if (insert_mode) begin
                        // INSERT в main: приймаємо тільки якщо <= MAX_FREQ_HZ
                        if (candidate_ok_insert) begin
                            digit[0] <= digit[1];
                            digit[1] <= digit[2];
                            digit[2] <= digit[3];
                            digit[3] <= digit[4];
                            digit[4] <= digit[5];
                            digit[5] <= digit[6];
                            digit[6] <= digit[7];
                            digit[7] <= key_data_out;
                            need_redraw_clk <= 1;
                        end
                        // інакше - мовчазне відхилення
                    end else begin
                        // REPLACE в main: приймаємо тільки якщо <= MAX_FREQ_HZ
                        if (candidate_ok_replace) begin
                            digit[cursor_pos] <= key_data_out;
                            if (cursor_pos < max_cursor)
                                cursor_pos <= cursor_pos + 4'd1;
                            need_redraw_clk <= 1;
                        end
                        // інакше - мовчазне відхилення
                    end
                end

                // ── A - курсор вліво ─────────────────────────
                4'hA: begin
                    cursor_hidden <= 1'b0;
                    if (cursor_in_pwm && cursor_pos == 4'd8)
                        cursor_pos <= 4'd7;             // PWM → main
                    else if (cursor_pos > field_min)
                        cursor_pos <= cursor_pos - 4'd1;
                    need_redraw_clk <= 1;
                end

                // ── B - курсор вправо ────────────────────────
                4'hB: begin
                    cursor_hidden <= 1'b0;
                    if (cursor_pos < max_cursor)
                        cursor_pos <= cursor_pos + 4'd1;
                    need_redraw_clk <= 1;
                end

                // ── C - очистити поточне поле ────────────────
                4'hC: begin
                    cursor_hidden <= 1'b0;
                    if (cursor_in_pwm) begin
                        pwm_digit[0] <= 0; pwm_digit[1] <= 0;
                        pwm_digit[2] <= 0; pwm_digit[3] <= 0;
                        cursor_pos   <= 4'd8;
                    end else begin
                        for (ki = 0; ki < DIGIT_COUNT; ki = ki + 1) digit[ki] <= 0;
                        cursor_pos <= insert_mode ? 4'd7 : 4'd0;
                    end
                    need_redraw_clk <= 1;
                end

                // ── D - Enter: commit число в digit_backup[wave_type] + ховати курсор
                // DDS читає freq саме з digit_backup → після Enter DDS переключається
                4'hD: begin
                    digit_backup[{wave_type, 3'd0}] <= digit[0];
                    digit_backup[{wave_type, 3'd1}] <= digit[1];
                    digit_backup[{wave_type, 3'd2}] <= digit[2];
                    digit_backup[{wave_type, 3'd3}] <= digit[3];
                    digit_backup[{wave_type, 3'd4}] <= digit[4];
                    digit_backup[{wave_type, 3'd5}] <= digit[5];
                    digit_backup[{wave_type, 3'd6}] <= digit[6];
                    digit_backup[{wave_type, 3'd7}] <= digit[7];
                    cursor_hidden   <= 1'b1;
                    need_redraw_clk <= 1;
                end

                // ── * - перемкнути режим вставки/заміни ──────
                4'hE: begin
                    cursor_hidden <= 1'b0;
                    insert_mode <= ~insert_mode;
                    // при переході REPLACE → INSERT (в main) переходимо до 7
                    if (!insert_mode && !cursor_in_pwm)
                        cursor_pos <= 4'd7;
                    need_redraw_clk <= 1;
                end

                // ── # - перемкнути тип сигналу ───────────────
                // Зберігаємо поточні цифри під поточним wave_type
                // та завантажуємо збережені для wave_type_next
                4'hF: begin
                    cursor_hidden <= 1'b0;
                    digit_backup[{wave_type, 3'd0}] <= digit[0];
                    digit_backup[{wave_type, 3'd1}] <= digit[1];
                    digit_backup[{wave_type, 3'd2}] <= digit[2];
                    digit_backup[{wave_type, 3'd3}] <= digit[3];
                    digit_backup[{wave_type, 3'd4}] <= digit[4];
                    digit_backup[{wave_type, 3'd5}] <= digit[5];
                    digit_backup[{wave_type, 3'd6}] <= digit[6];
                    digit_backup[{wave_type, 3'd7}] <= digit[7];
                    digit[0] <= digit_backup[{wave_type_next, 3'd0}];
                    digit[1] <= digit_backup[{wave_type_next, 3'd1}];
                    digit[2] <= digit_backup[{wave_type_next, 3'd2}];
                    digit[3] <= digit_backup[{wave_type_next, 3'd3}];
                    digit[4] <= digit_backup[{wave_type_next, 3'd4}];
                    digit[5] <= digit_backup[{wave_type_next, 3'd5}];
                    digit[6] <= digit_backup[{wave_type_next, 3'd6}];
                    digit[7] <= digit_backup[{wave_type_next, 3'd7}];
                    wave_type  <= wave_type_next;
                    // курсор у початок нового поля main
                    cursor_pos <= insert_mode ? 4'd7 : 4'd0;
                    need_redraw_clk <= 1;
                end

                default: begin end
            endcase
        end
    end
end

// ────────────────────────────────────────────────────────────
// Перша значуща цифра основного числа (для прихованих нулів)
//   first_sig = найлівіша позиція з digit!=0; якщо всі 0 → 7
// ────────────────────────────────────────────────────────────
wire [2:0] first_sig =
    (digit_lcd[0] != 0) ? 3'd0 :
    (digit_lcd[1] != 0) ? 3'd1 :
    (digit_lcd[2] != 0) ? 3'd2 :
    (digit_lcd[3] != 0) ? 3'd3 :
    (digit_lcd[4] != 0) ? 3'd4 :
    (digit_lcd[5] != 0) ? 3'd5 :
    (digit_lcd[6] != 0) ? 3'd6 :
    3'd7;

// ────────────────────────────────────────────────────────────
// Shadow-регістри в lcd_clk домені.
// Захоплюються тільки на rising edge need_redraw - тобто ПІСЛЯ того
// як kbd_clk вже стабілізував digit[], cursor_pos тощо.
// Це усуває глюки first_sig від CDC (FSM малює 16+ тактів - за цей час
// digit[] може глюкнути якщо читати напряму).
// ────────────────────────────────────────────────────────────
(* ASYNC_REG = "TRUE" *) reg [3:0] digit_lcd     [0:7];
(* ASYNC_REG = "TRUE" *) reg [3:0] pwm_digit_lcd [0:3];
(* ASYNC_REG = "TRUE" *) reg [1:0] wave_type_lcd;
(* ASYNC_REG = "TRUE" *) reg [3:0] cursor_pos_lcd;
(* ASYNC_REG = "TRUE" *) reg       insert_mode_lcd;
(* ASYNC_REG = "TRUE" *) reg       cursor_hidden_lcd;
wire cursor_in_pwm_lcd = cursor_pos_lcd[3];

// ────────────────────────────────────────────────────────────
// CDC: need_redraw_clk (clk) → lcd_clk
// ────────────────────────────────────────────────────────────
(* ASYNC_REG = "TRUE" *) reg need_redraw_s1, need_redraw_s2, need_redraw_s3;
wire need_redraw;
always @(posedge lcd_clk or negedge reset_n) begin
    if (!reset_n) begin
        need_redraw_s1 <= 0;
        need_redraw_s2 <= 0;
        need_redraw_s3 <= 0;
    end else begin
        need_redraw_s1 <= need_redraw_clk;
        need_redraw_s2 <= need_redraw_s1;
        need_redraw_s3 <= need_redraw_s2;
    end
end
assign need_redraw = need_redraw_s2 & ~need_redraw_s3;

// Захоплення всього kbd-стану в lcd_clk на rising edge need_redraw
integer sl;
always @(posedge lcd_clk or negedge reset_n) begin
    if (!reset_n) begin
        for (sl = 0; sl < 8; sl = sl + 1) digit_lcd[sl]     <= 4'd0;
        for (sl = 0; sl < 4; sl = sl + 1) pwm_digit_lcd[sl] <= 4'd0;
        wave_type_lcd     <= 2'd0;
        cursor_pos_lcd    <= 4'd7;
        insert_mode_lcd   <= 1'b1;
        cursor_hidden_lcd <= 1'b0;
    end else if (need_redraw) begin
        digit_lcd[0] <= digit[0]; digit_lcd[1] <= digit[1];
        digit_lcd[2] <= digit[2]; digit_lcd[3] <= digit[3];
        digit_lcd[4] <= digit[4]; digit_lcd[5] <= digit[5];
        digit_lcd[6] <= digit[6]; digit_lcd[7] <= digit[7];
        pwm_digit_lcd[0] <= pwm_digit[0]; pwm_digit_lcd[1] <= pwm_digit[1];
        pwm_digit_lcd[2] <= pwm_digit[2]; pwm_digit_lcd[3] <= pwm_digit[3];
        wave_type_lcd     <= wave_type;
        cursor_pos_lcd    <= cursor_pos;
        insert_mode_lcd   <= insert_mode;
        cursor_hidden_lcd <= cursor_hidden;
    end
end

// ────────────────────────────────────────────────────────────
// BRAM, LCD, Touch, SDRAM
// ────────────────────────────────────────────────────────────
blk_mem_gen_0 bram (.clka(lcd_clk), .addra(bram_addra), .douta(bram_douta));

// ── Icon ROM ──
wire        icon_pixel;
reg  [14:0] icon_addr_reg;
reg         drawing_icon;

wire [14:0] icon_base =
    wave_type_lcd == WAVE_SINE     ? 15'd0     :
    wave_type_lcd == WAVE_SQUARE   ? 15'd8000  :
    wave_type_lcd == WAVE_TRIANGLE ? 15'd16000 :
                                     15'd24000;

wire [15:0] mode_bg_color =
    wave_type_lcd == WAVE_SINE     ? MODE_COLOR_SINE     :
    wave_type_lcd == WAVE_SQUARE   ? MODE_COLOR_SQUARE   :
    wave_type_lcd == WAVE_TRIANGLE ? MODE_COLOR_TRIANGLE :
                                     MODE_COLOR_PWM;

icon_rom icon_rom_inst (
    .clk  (lcd_clk),
    .addr (icon_addr_reg),
    .pixel(icon_pixel)
);

lcd lcd_inst (
    .clk(clk), .reset_n(reset_n),
    .fill_color(pixel_data),
    .x_start(x_start), .x_end(x_end),
    .y_start(y_start), .y_end(y_end),
    .update_screen(update_screen),
    .LCD_DATA(LCD_DATA), .LCD_WR(LCD_WR), .LCD_RS(LCD_RS),
    .LCD_CS(LCD_CS), .LCD_RESET(LCD_RESET), .LCD_BL(LCD_BL),
    .LCD_RDX(LCD_RDX),
    .start_read_data(start_read_data),
    .cmd_done(cmd_done), .cmd_data_done(cmd_data_done),
    .cmd_ndata_done(cmd_ndata_done),
    .lcd_clk(lcd_clk),       // вхід - тактуємо LCD з зовнішнього PLL
    .lcd_state(lcd_state),
    .init_done(init_done), .lcd_data_count(data_count)
);

xpt2046 touch_inst (
    .Clk50m(clk), .Rst_n(reset_n), .EN(1'b0),
    .X_Value(), .Y_Value(), .Get_Flag(),
    .PenIrq_n(ts_pen), .DCLK(ts_clk),
    .DIN(ts_mosi), .DOUT(ts_miso),
    .CS_N(ts_cs), .BUSY(1'b0)
);

assign SDRAM_CKE = 0; assign SDRAM_WEn = 1;
assign SDRAM_CASn = 1; assign SDRAM_RASn = 1;
assign SDRAM_DQ = 16'hzzzz;

// ════════════════════════════════════════════════════════════
// ОБЧИСЛЕННЯ ЧАСТОТИ І PHASE_INC ДЛЯ DDS
// ════════════════════════════════════════════════════════════
//   freq_hz = digit[0]*10^7 + digit[1]*10^6 + ... + digit[7]
//   phase_inc = freq_hz * 2^32 / 165_000_000
//   K_fixed = round(2^48 / 165e6) = 1705716
//   phase_inc = (freq * K_fixed) >> 16
// ────────────────────────────────────────────────────────────
reg  [26:0] freq_hz;
reg  [31:0] phase_inc;
reg  [13:0] pwm_duty;       // 0..9999 (XX.XX %)
reg  [13:0] pwm_threshold;  // 0..16383 для DDS

always @(posedge clk_main) begin
    // DDS читає committed значення з digit_backup[wave_type]
    freq_hz <= digit_backup[{wave_type, 3'd0}]*27'd10_000_000 +
               digit_backup[{wave_type, 3'd1}]*27'd1_000_000  +
               digit_backup[{wave_type, 3'd2}]*27'd100_000    +
               digit_backup[{wave_type, 3'd3}]*27'd10_000     +
               digit_backup[{wave_type, 3'd4}]*27'd1_000      +
               digit_backup[{wave_type, 3'd5}]*27'd100        +
               digit_backup[{wave_type, 3'd6}]*27'd10         +
               digit_backup[{wave_type, 3'd7}];

    // phase_inc = freq_hz * 2^32 / 165_000_000
    // K_fixed = round(2^48 / 165e6) = 1_705_716
    // КРИТИЧНО: розширюємо до 48 біт!
    // Без розширення Verilog обчислює як 32-біт: overflow вже при ~2.5 кГц.
    // Приклад: 10 кГц × 1705716 = 17 млрд > 2^32 → неправильний phase_inc.
    phase_inc <= ({21'd0, freq_hz} * 48'd1_705_716) >> 16;

    pwm_duty  <= pwm_digit[0]*14'd1000 + pwm_digit[1]*14'd100 +
                 pwm_digit[2]*14'd10   + pwm_digit[3];

    // threshold = pwm_duty * 16384 / 10000  ≈  pwm_duty * 107374 / 2^16
    pwm_threshold <= (pwm_duty * 32'd107374) >> 16;
end

// ════════════════════════════════════════════════════════════
// CDC: phase_inc, pwm_threshold, wave_type (clk_main → clk_dac)
// Дані змінюються рідко (натискання клавіш), 2-FF синхронізації
// достатньо
// ════════════════════════════════════════════════════════════
(* ASYNC_REG = "TRUE" *) reg [31:0] phase_inc_s1, phase_inc_s2;
(* ASYNC_REG = "TRUE" *) reg [13:0] pwm_thr_s1, pwm_thr_s2;
(* ASYNC_REG = "TRUE" *) reg [1:0]  wave_type_s1, wave_type_s2;

always @(posedge clk_dac or negedge reset_n) begin
    if (!reset_n) begin
        phase_inc_s1 <= 0; phase_inc_s2 <= 0;
        pwm_thr_s1   <= 0; pwm_thr_s2   <= 0;
        wave_type_s1 <= 0; wave_type_s2 <= 0;
    end else begin
        phase_inc_s1 <= phase_inc;  phase_inc_s2 <= phase_inc_s1;
        pwm_thr_s1   <= pwm_threshold; pwm_thr_s2 <= pwm_thr_s1;
        wave_type_s1 <= wave_type;  wave_type_s2 <= wave_type_s1;
    end
end

// ════════════════════════════════════════════════════════════
// DDS - генерація 14-біт сигналу на ЦАП
// ════════════════════════════════════════════════════════════
wire [13:0] dac_value;
dds dds_inst (
    .clk          (clk_dac),
    .reset_n      (reset_n & pll_locked),
    .phase_inc    (phase_inc_s2),
    .wave_type    (wave_type_s2),
    .pwm_threshold(pwm_thr_s2),
    .dac_out      (dac_value)
);

// ── DAC виходи ──────────────────────────────────────────────────
// (* IOB = "TRUE" *) розміщує FF в IOB → мінімальна затримка clock-to-output.
// Це критично для 165 МГц: data і clock мають йти з мінімальним skew.
// DAC904 MODE pin:
//   MODE = LOW  → straight binary   (0x0000=min, 0x2000=mid, 0x3FFF=max)
//   MODE = HIGH → two's complement  (0x2000=min, 0x0000=mid, 0x1FFF=max)
// Встанови DAC_TWOS_COMPLEMENT = 1 якщо MODE=HIGH (two's complement)
localparam DAC_TWOS_COMPLEMENT = 0;

wire [13:0] dac_formatted = DAC_TWOS_COMPLEMENT
    ? {~dac_value[13], dac_value[12:0]}  // XOR MSB: straight→two's complement
    :  dac_value;                          // straight binary (за замовчуванням)

(* IOB = "TRUE" *) reg [13:0] dac_data_reg;
always @(posedge clk_dac or negedge reset_n) begin
    if (!reset_n) dac_data_reg <= 14'd0;
    else          dac_data_reg <= dac_formatted;
end
assign DAC_DATA = dac_data_reg;

// DAC_CLK через ODDR - стандартний спосіб форвардингу тактового на 165 МГц.
// Без ODDR PLL-CLK → OBUF має великий skew відносно даних → DAC не засемплює коректно.
ODDR #(
    .DDR_CLK_EDGE("SAME_EDGE"),
    .INIT        (1'b0),
    .SRTYPE      ("SYNC")
) oddr_dac_clk (
    .Q (DAC_CLK),
    .C (clk_dac),
    .CE(1'b1),
    .D1(1'b1),   // HIGH на rising edge → форвардимо clk_dac як є
    .D2(1'b0),   // LOW  на falling edge
    .R (1'b0),
    .S (1'b0)
);

// ── Тест-вихід: clk_dac / 100 = 1.65 МГц ──────────────────
// Лічильник 0..49 → toggle → 50% duty cycle, 165/100 = 1.65 МГц
reg [5:0] dac_test_cnt;
reg       dac_test_reg;

always @(posedge clk_dac or negedge reset_n) begin
    if (!reset_n) begin
        dac_test_cnt <= 6'd0;
        dac_test_reg <= 1'b0;
    end else if (dac_test_cnt == 6'd49) begin
        dac_test_cnt <= 6'd0;
        dac_test_reg <= ~dac_test_reg;  // toggle кожні 50 тактів
    end else begin
        dac_test_cnt <= dac_test_cnt + 6'd1;
    end
end

assign DAC_CLK_TEST = dac_test_reg;

// ════════════════════════════════════════════════════════════
// MAIN FSM малювання
// ════════════════════════════════════════════════════════════
localparam TS_INIT      = 3'd0,
           TS_INIT_FILL = 3'd1,
           TS_INIT_WAIT = 3'd2,
           TS_IDLE      = 3'd3,
           TS_PREP      = 3'd4,
           TS_TRIGGER   = 3'd5,
           TS_DISPLAY   = 3'd6,
           TS_DONE_STEP = 3'd7;

reg [2:0] ts_state;
reg [4:0] draw_step;
reg       init_fill_done;

// Допоміжна змінна для PREP
reg [2:0] idx3;

always @(posedge lcd_clk or negedge reset_n) begin
    if (!reset_n) begin
        ts_state       <= TS_INIT;
        update_screen  <= 0;
        draw_step      <= 0;
        init_fill_done <= 0;
        solid_fill     <= 0;
        solid_color    <= BG_COLOR;
        bram_addra     <= 0;
        bram_base_addra<= 0;
        icon_addr_reg  <= 0;
        drawing_icon   <= 0;
        x_start <= 0; x_end <= DIGIT_W - 1;
        y_start <= 0; y_end <= DIGIT_H - 1;
        idx3 <= 0;
    end else begin
        case (ts_state)

            TS_INIT: begin
                if (init_done && !init_fill_done) begin
                    solid_fill  <= 1;
                    solid_color <= BG_COLOR;
                    x_start <= 0; x_end <= 16'd799;
                    y_start <= 0; y_end <= 16'd479;
                    ts_state    <= TS_INIT_FILL;
                end
            end

            TS_INIT_FILL: begin
                update_screen <= 1;
                ts_state      <= TS_INIT_WAIT;
            end

            TS_INIT_WAIT: begin
                update_screen <= 0;
                if (cmd_ndata_done) begin
                    init_fill_done <= 1;
                    solid_fill     <= 0;
                    draw_step      <= STEP_FIRST;
                    ts_state       <= TS_PREP;
                end
            end

            TS_IDLE: begin
                update_screen <= 0;
                if (need_redraw) begin
                    draw_step <= STEP_FIRST;
                    ts_state  <= TS_PREP;
                end
            end

            // ── Підготовка координат для кожного кроку ──
            TS_PREP: begin
                update_screen <= 0;

                // ── Кроки 1..8: основні цифри ──
                if (draw_step >= 5'd1 && draw_step <= 5'd8) begin
                    idx3 = draw_step[2:0] - 3'd1;
                    // Логіка прихованих нулів:
                    //   ховаємо нуль ліворуч від first_sig,
                    //   АЛЕ якщо курсор стоїть на цій позиції (і він не у PWM) -
                    //   показуємо цифру
                    if (idx3 < first_sig &&
                        !(!cursor_in_pwm_lcd && !cursor_hidden_lcd &&
                          idx3 == cursor_pos_lcd[2:0])) begin
                        solid_fill  <= 1;
                        solid_color <= BG_COLOR;
                    end else begin
                        solid_fill      <= 0;
                        bram_base_addra <= digit_lcd[idx3] * (DIGIT_W * DIGIT_H);
                    end
                    x_start <= MAIN_X0 + {13'd0, idx3} * DIGIT_W;
                    x_end   <= MAIN_X0 + {13'd0, idx3} * DIGIT_W + DIGIT_W - 1;
                    y_start <= MAIN_Y;
                    y_end   <= MAIN_Y + DIGIT_H - 1;
                    ts_state <= TS_TRIGGER;

                // ── Кроки 9..16: курсорні смужки під основними ──
                // Видимі тільки в REPLACE-режимі. У INSERT-режимі - фон.
                end else if (draw_step >= 5'd9 && draw_step <= 5'd16) begin
                    idx3 = draw_step[2:0] - 3'd1;
                    solid_fill  <= 1;
                    solid_color <= (!cursor_hidden_lcd && !cursor_in_pwm_lcd &&
                                     !insert_mode_lcd &&
                                     idx3 == cursor_pos_lcd[2:0])
                                     ? CURSOR_COLOR : BG_COLOR;
                    x_start <= MAIN_X0 + {13'd0, idx3} * DIGIT_W;
                    x_end   <= MAIN_X0 + {13'd0, idx3} * DIGIT_W + DIGIT_W - 1;
                    y_start <= MAIN_Y + DIGIT_H;
                    y_end   <= MAIN_Y + DIGIT_H + CURSOR_H - 1;
                    ts_state <= TS_TRIGGER;

                // ── Кроки 17..20: цифри ШИМ (4 цифри) ──
                end else if (draw_step >= 5'd17 && draw_step <= 5'd20) begin
                    idx3 = draw_step[2:0] - 3'd1; // 17-1=16->[2:0]=0 ✓ ... 20-1=19->[2:0]=3
                    if (wave_type_lcd == WAVE_PWM) begin
                        solid_fill      <= 0;
                        bram_base_addra <= pwm_digit_lcd[idx3[1:0]] * (DIGIT_W * DIGIT_H);
                    end else begin
                        solid_fill  <= 1;
                        solid_color <= BG_COLOR;
                    end
                    // позиція: PWM_X0 + i*DIGIT_W, з пропуском під точку між 1 і 2
                    if (idx3[1:0] <= 2'd1)
                        x_start <= PWM_X0 + {13'd0, idx3[1:0]} * DIGIT_W;
                    else
                        x_start <= PWM_X0 + {13'd0, idx3[1:0]} * DIGIT_W + DOT_W;
                    if (idx3[1:0] <= 2'd1)
                        x_end <= PWM_X0 + {13'd0, idx3[1:0]} * DIGIT_W + DIGIT_W - 1;
                    else
                        x_end <= PWM_X0 + {13'd0, idx3[1:0]} * DIGIT_W + DOT_W + DIGIT_W - 1;
                    y_start <= PWM_Y;
                    y_end   <= PWM_Y + DIGIT_H - 1;
                    ts_state <= TS_TRIGGER;

                // ── Кроки 21..24: курсорні смужки під ШИМ ──
                end else if (draw_step >= 5'd21 && draw_step <= 5'd24) begin
                    idx3 = draw_step[2:0] - 3'd5; // 21-5=16->[2:0]=0 ... 24-5=19->[2:0]=3
                    solid_fill  <= 1;
                    if (!cursor_hidden_lcd && wave_type_lcd == WAVE_PWM &&
                        cursor_in_pwm_lcd &&
                        (cursor_pos_lcd - 4'd8) == {2'd0, idx3[1:0]})
                        solid_color <= CURSOR_COLOR;
                    else
                        solid_color <= BG_COLOR;
                    if (idx3[1:0] <= 2'd1)
                        x_start <= PWM_X0 + {13'd0, idx3[1:0]} * DIGIT_W;
                    else
                        x_start <= PWM_X0 + {13'd0, idx3[1:0]} * DIGIT_W + DOT_W;
                    if (idx3[1:0] <= 2'd1)
                        x_end <= PWM_X0 + {13'd0, idx3[1:0]} * DIGIT_W + DIGIT_W - 1;
                    else
                        x_end <= PWM_X0 + {13'd0, idx3[1:0]} * DIGIT_W + DOT_W + DIGIT_W - 1;
                    y_start <= PWM_Y + DIGIT_H;
                    y_end   <= PWM_Y + DIGIT_H + CURSOR_H - 1;
                    ts_state <= TS_TRIGGER;

                // ── Крок 25: десяткова точка для ШИМ ──
                end else if (draw_step == 5'd25) begin
                    solid_fill  <= 1;
                    solid_color <= (wave_type_lcd == WAVE_PWM) ? FG_COLOR : BG_COLOR;
                    x_start <= PWM_X0 + 2 * DIGIT_W;
                    x_end   <= PWM_X0 + 2 * DIGIT_W + DOT_W - 1;
                    y_start <= PWM_Y + DIGIT_H - DOT_SIZE - 4;
                    y_end   <= PWM_Y + DIGIT_H - 4;
                    ts_state <= TS_TRIGGER;

                // ── Крок 26: іконка режиму DDS (з icon_rom) ──
                end else if (draw_step == 5'd26) begin
                    solid_fill      <= 0;
                    drawing_icon    <= 1;
                    bram_base_addra <= 0;
                    x_start <= MODE_X0;
                    x_end   <= MODE_X1;
                    y_start <= MODE_Y0;
                    y_end   <= MODE_Y1;
                    ts_state <= TS_TRIGGER;

                // ── Крок 27: вертикальний курсор (INSERT mode) ──
                // Виводимо тонку вертикальну смужку справа від позиції 7.
                // CURSOR_COLOR - коли в режимі вставки в main, інакше BG
                end else if (draw_step == 5'd27) begin
                    solid_fill  <= 1;
                    solid_color <= (!cursor_hidden_lcd && insert_mode_lcd && !cursor_in_pwm_lcd)
                                     ? CURSOR_COLOR : BG_COLOR;
                    x_start <= MAIN_X0 + 8 * DIGIT_W;
                    x_end   <= MAIN_X0 + 8 * DIGIT_W + CURSOR_H - 1;
                    y_start <= MAIN_Y;
                    y_end   <= MAIN_Y + DIGIT_H - 1;
                    ts_state <= TS_TRIGGER;

                end else begin
                    draw_step <= 0;
                    ts_state  <= TS_IDLE;
                end
            end

            TS_TRIGGER: begin
                update_screen <= 1;
                ts_state      <= TS_DISPLAY;
            end

            TS_DISPLAY: begin
                update_screen <= 0;
                if (start_read_data && !solid_fill) begin
                    if (drawing_icon)
                        icon_addr_reg <= icon_base + data_count[14:0];
                    else
                        bram_addra <= bram_base_addra + data_count;
                end
                if (cmd_ndata_done) begin
                    drawing_icon <= 0;
                    ts_state     <= TS_DONE_STEP;
                end
            end

            TS_DONE_STEP: begin
                draw_step <= draw_step + 5'd1;
                ts_state  <= TS_PREP;
            end

            default: ts_state <= TS_IDLE;
        endcase
    end
end

endmodule