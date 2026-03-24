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
    output  [8:0] la_out,

    // Клавіатура 4x4
    input  [3:0]  row_data_in,     // рядки від клавіатури
    output [3:0]  col_data_out      // стовпці (керуємо ми)
);

reg led_1_reg;
assign led_1 = led_1_reg;

// LCD сигнали
reg  [15:0] pixel_data;
reg  update_screen;
reg  init_done;
reg [31:0] data_count;
reg  start_read_data;
reg  cmd_done;
reg  cmd_data_done;
reg  cmd_ndata_done;
reg  [15:0] x_start, x_end, y_start, y_end;
reg  [4:0]  state;
reg  [4:0]  lcd_state;

// BRAM
wire bram_douta;
reg  [17:0] bram_addra;

wire clk_main;
clk_wiz_1 main_clk_pll (
    .clk_in1(clk),
    .resetn(reset_n),
    .clk_out1(clk_main)
);

// FSM States
localparam S_INIT         = 0,
           S_IDLE         = 1,
           S_PREP_DRAW    = 2,
           S_TRIGGER_WAIT = 3,
           S_DISPLAY      = 4,
           S_DONE_DRAW    = 5,
           S_INIT_FILL    = 6,
           S_INIT_WAIT    = 7;   // очікування завершення початкового заповнення

// Режим введення та буфер на 8 цифр
reg input_mode;                        // 0 = звичайний режим, 1 = режим введення (після A)
reg [3:0] input_buffer [0:7];          // 8 цифр для введення
integer i;
initial begin
    input_mode = 0;
    for (i = 0; i < 8; i = i + 1) input_buffer[i] = i;
end

// need_update - єдиний власник: main FSM
// key_pulse, timer_pulse - однотактні імпульси, кожен пишеться тільки зі свого блоку.
// Main FSM їх тільки читає - запису немає, тому multi-driver виключено.
reg need_update;
reg key_pulse;      // імпульс від клавіатури (1 такт), власник: блок клавіатури
reg timer_pulse;    // імпульс від таймера   (1 такт), власник: блок таймера
reg draw_in_progress;
reg solid_fill;
reg init_fill_done;     // прапор: початкове заповнення фоном виконано один раз
reg [15:0] solid_color;
reg [17:0] bram_base_addra;
reg [5:0] draw_step;

assign la_out[5:0] = draw_step;
assign la_out[6]   = need_update;
assign la_out[7]   = input_mode;
assign la_out[8]   = clk_main;

// BRAM
blk_mem_gen_0 bram (
    .clka(clk_main),
    .addra(bram_addra),
    .douta(bram_douta)
);

// LCD instance
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

// --------------------------------------------------------------------------
// Клавіатура 4x4
// key_read_ack - окремий сигнал підтвердження для KeyRead (однотактний імпульс)
// key_ready    - вихід KeyReady зі сканера (рівневий, утримується до підтвердження)
// key_prev_ready - для детектування переднього фронту KeyReady
// --------------------------------------------------------------------------
wire       key_ready;
wire [3:0] key_value;
reg        key_read_ack;    // підтвердження прочитання → KeyRead
reg        key_prev_ready;  // попередній стан KeyReady для детекції фронту

KeyPadInterpreter keypad_inst (
    .Clock      (clk_main),
    .ResetButton(~reset_n),
    .KeyRead    (key_read_ack),  // ← окремий сигнал підтвердження
    .RowDataIn  (row_data_in),
    .KeyReady   (key_ready),     // ← окремий вихід готовності
    .DataOut    (key_value),
    .ColDataOut (col_data_out),
    .PressCount ()
);

// --------------------------------------------------------------------------
// Обробка натискань клавіш
//
// Логіка:
//   1. Детектуємо передній фронт key_ready (0→1) через key_prev_ready.
//      Це гарантує що подія обробляється рівно один раз, незалежно від
//      того скільки тактів KeyReady залишається HIGH.
//   2. Після обробки виставляємо key_read_ack = 1 на один такт -
//      сканер побачить KeyRd=1, скине KeyRdy і продовжить сканування.
//   3. need_update виставляється тільки якщо малювання не йде.
// --------------------------------------------------------------------------
always @(posedge clk_main or negedge reset_n) begin
    if (!reset_n) begin
        input_mode     <= 0;
        key_read_ack   <= 0;
        key_prev_ready <= 0;
        key_pulse      <= 0;
        for (i = 0; i < 8; i = i + 1) input_buffer[i] <= 0;
    end else begin
        key_read_ack   <= 0;   // однотактний імпульс - за замовчуванням 0
        key_pulse      <= 0;   // однотактний імпульс - за замовчуванням 0
        key_prev_ready <= key_ready;

        if (key_ready && !key_prev_ready) begin
            key_read_ack <= 1;

            if (!draw_in_progress) begin
                case (key_value)
                    4'hA: begin input_mode <= 1; key_pulse <= 1; end
                    4'hB: begin input_mode <= 0; key_pulse <= 1; end
                    4'h0, 4'h1, 4'h2, 4'h3, 4'h4,
                    4'h5, 4'h6, 4'h7, 4'h8, 4'h9: begin
                        if (input_mode) begin
                            for (i = 0; i < 7; i = i + 1)
                                input_buffer[i] <= input_buffer[i+1];
                            input_buffer[7] <= key_value;
                            key_pulse <= 1;
                        end
                    end
                    default: begin end
                endcase
            end
        end
    end
end

// --------------------------------------------------------------------------
// 60 Hz таймер - генерує однотактний імпульс timer_pulse.
// timer_pulse пишеться ТІЛЬКИ тут. Main FSM його тільки читає.
// --------------------------------------------------------------------------
reg [31:0] refresh_counter;
always @(posedge clk_main or negedge reset_n) begin
    if (!reset_n) begin
        refresh_counter <= 0;
        led_1_reg       <= 0;
        timer_pulse     <= 0;
    end else begin
        timer_pulse <= 0;   // однотактний імпульс - за замовчуванням 0
        if (refresh_counter >= SCREEN_REFRESH_TICKS - 1) begin
            refresh_counter <= 0;
            led_1_reg       <= ~led_1_reg;
            timer_pulse     <= 1;
        end else begin
            refresh_counter <= refresh_counter + 1;
        end
    end
end

// --------------------------------------------------------------------------
// Pixel data
// При solid_fill - суцільний колір; інакше - піксель із BRAM з фоном
// --------------------------------------------------------------------------
assign pixel_data = solid_fill ? solid_color
                               : (bram_douta ? TEXT_COLOR : TEXT_BACK_COLOR);

// --------------------------------------------------------------------------
// MAIN FSM
// --------------------------------------------------------------------------
always @(posedge clk_main or negedge reset_n) begin
    if (!reset_n) begin
        bram_addra       <= 0;
        bram_base_addra  <= 0;
        state            <= S_INIT;
        update_screen    <= 0;
        x_start          <= 0;
        x_end            <= `DISPLAY_WIDTH - 1;
        y_start          <= 0;
        y_end            <= `DISPLAY_HEIGH - 1;
        draw_step        <= 0;
        solid_fill       <= 0;
        solid_color      <= TEXT_BACK_COLOR;
        need_update      <= 0;
        draw_in_progress <= 0;
        init_fill_done   <= 0;
    end else begin

        // ------------------------------------------------------------------
        // Обробка імпульсів від клавіатури і таймера.
        // Читаємо key_pulse / timer_pulse - не пишемо їх тут.
        // need_update - єдиний власник цей блок.
        // ------------------------------------------------------------------
        if ((key_pulse || timer_pulse) && !draw_in_progress)
            need_update <= 1;

        case (state)

            // ------------------------------------------------------------------
            // Чекаємо на завершення ініціалізації LCD
            // ------------------------------------------------------------------
            S_INIT: begin
                if (init_done && !init_fill_done) begin
                    // Один раз заповнюємо весь екран фоновим кольором
                    solid_fill      <= 1;
                    solid_color     <= TEXT_BACK_COLOR;
                    x_start         <= 0;
                    x_end           <= `DISPLAY_WIDTH - 1;
                    y_start         <= 0;
                    y_end           <= `DISPLAY_HEIGH - 1;
                    draw_in_progress<= 1;
                    state           <= S_INIT_FILL;
                end
            end

            // ------------------------------------------------------------------
            // Тригер початкового заповнення
            // ------------------------------------------------------------------
            S_INIT_FILL: begin
                update_screen <= 1;
                state         <= S_INIT_WAIT;
            end

            // ------------------------------------------------------------------
            // Чекаємо завершення початкового заповнення
            // ------------------------------------------------------------------
            S_INIT_WAIT: begin
                update_screen <= 0;
                if (cmd_ndata_done) begin
                    init_fill_done   <= 1;
                    draw_in_progress <= 0;
                    need_update      <= 1;  // перший запит малювання цифр
                    state            <= S_IDLE;
                end
            end

            // ------------------------------------------------------------------
            // IDLE: чекаємо на need_update
            // ------------------------------------------------------------------
            S_IDLE: begin
                update_screen <= 0;
                if (need_update && !draw_in_progress) begin
                    need_update     <= 0;
                    draw_in_progress<= 1;
                    draw_step       <= 0;
                    state           <= S_PREP_DRAW;
                end
            end

            // ------------------------------------------------------------------
            // PREP_DRAW: підготовка параметрів для кожного кроку малювання
            // Крок 0    - підсвітка режиму (смужка зверху)
            // Кроки 1-8 - малювання 8 цифр (з фоном із BRAM)
            // Крок 9    - завершення циклу
            // ------------------------------------------------------------------
            S_PREP_DRAW: begin
                update_screen <= 0;

                case (draw_step)

                    // Крок 0: підсвітка режиму введення (смужка вгорі)
                    0: begin
                        solid_fill  <= 1;
                        solid_color <= input_mode ? 16'hF800 : TEXT_BACK_COLOR;
                        x_start     <= 0;
                        x_end       <= `DISPLAY_WIDTH - 1;
                        y_start     <= 0;
                        y_end       <= 10;
                        state       <= S_TRIGGER_WAIT;
                    end

                    // Кроки 1-8: малювання цифр із фоном (solid_fill=0 → BRAM)
                    1: draw_digit(0);
                    2: draw_digit(1);
                    3: draw_digit(2);
                    4: draw_digit(3);
                    5: draw_digit(4);
                    6: draw_digit(5);
                    7: draw_digit(6);
                    8: draw_digit(7);

                    // Крок 9: всі кроки завершено
                    9: begin
                        draw_in_progress <= 0;
                        draw_step        <= 0;
                        state            <= S_IDLE;
                    end

                    default: draw_step <= draw_step + 1;
                endcase
            end

            // ------------------------------------------------------------------
            // Виставляємо update_screen на один такт для LCD FSM
            // ------------------------------------------------------------------
            S_TRIGGER_WAIT: begin
                update_screen <= 1;
                state         <= S_DISPLAY;
            end

            // ------------------------------------------------------------------
            // Чекаємо завершення передачі пікселів
            // ------------------------------------------------------------------
            S_DISPLAY: begin
                update_screen <= 0;
                if (start_read_data && !solid_fill) begin
                    bram_addra <= bram_base_addra + data_count;
                end
                if (cmd_ndata_done) state <= S_DONE_DRAW;
            end

            // ------------------------------------------------------------------
            // Крок завершено - переходимо до наступного
            // ------------------------------------------------------------------
            S_DONE_DRAW: begin
                draw_step <= draw_step + 1;
                state     <= S_PREP_DRAW;
            end

            default: state <= S_IDLE;
        endcase
    end
end

// --------------------------------------------------------------------------
// Task: підготовка параметрів для малювання однієї цифри
// solid_fill = 0 → pixel_data береться з BRAM (TEXT_COLOR або TEXT_BACK_COLOR)
// --------------------------------------------------------------------------
task draw_digit(input integer idx);
    begin
        solid_fill      <= 0;
        bram_base_addra <= input_buffer[idx] * (DIGIT_WIDTH * DIGIT_HEIGHT);
        x_start         <= DIGIT_X_START[idx];
        x_end           <= DIGIT_X_START[idx] + DIGIT_WIDTH - 1;
        y_start         <= DIGIT_Y;
        y_end           <= DIGIT_Y + DIGIT_HEIGHT - 1;
        state           <= S_TRIGGER_WAIT;
    end
endtask

endmodule
