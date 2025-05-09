module mrb3973_test (
    input            clk,        // Системний тактовий сигнал
    input            reset_n,    // Активний низький скид
    output    [15:0] LCD_DATA,   // Шина даних LCD
    output           LCD_WR,     // WRX (write control)
    output           LCD_RS,     // D/CX (0 - команда, 1 - дані)
    output           LCD_CS,     // CSX (активний низький)
    output           LCD_RESET,  // LCD reset (низький рівень)
    output           LCD_BL,     // Підсвітка
    output           LCD_RDX,    // RDX (read control)
    output           led_1,      // LED для дебагу
    output           led_2,      // LED для PLL
    output           lcd_clk,     // Тактовий сигнал для LCD
   output     [3:0] state_out,   // Вивід стану машини станів
   output     [9:0] init_rom_addr_out     // Лічильник адреси


);

    // Регістри для вихідних сигналів
    reg    [15:0] LCD_DATA_reg;
    reg           LCD_WR_reg;
    reg           LCD_RS_reg;
    reg           LCD_CS_reg;
    reg           LCD_RESET_reg;
    reg           LCD_BL_reg;
    reg           LCD_RDX_reg;

    assign LCD_DATA = LCD_DATA_reg;
    assign LCD_WR = LCD_WR_reg;
    assign LCD_RS = LCD_RS_reg;
    assign LCD_CS = LCD_CS_reg;
    assign LCD_RESET = LCD_RESET_reg;
    assign LCD_BL = LCD_BL_reg;
    assign LCD_RDX = LCD_RDX_reg;

   // Вивід стану машини станів на піни
    assign state_out = state;
    
    reg led_1_reg;
    reg led_2_reg;
    
    wire pll_locked;

    // PLL для генерації lcd_clk (8 МГц)
    clk_wiz_0 lcd_clk_pll (
        .clk_in1(clk),
        .resetn(reset_n),
        .clk_out1(lcd_clk),
        .locked(pll_locked)
    );
    
    assign led_1 = led_1_reg;
    assign led_2 = led_2_reg;
reg [ 15:0] init_rom [0:779]; //780lines
initial $readmemh("init.mem", init_rom);
    reg [9:0] init_rom_addr;     // Лічильник адреси
    
    assign init_rom_addr_out = init_rom_addr;
    
    // Дані та тип для запису
    reg [15:0] cmd_data;         // Команда або дані
    reg [15:0] write_data;       // Дані для модуля cmd_data

    // Станова машина
    reg [3:0] state;

    // Лічильник затримок
    reg [31:0] delay_counter;

    // Константи кольорів (RGB565)
    parameter RED = 16'hF800;

    // Загальна кількість пікселів для 800x480 дисплея
    parameter TOTAL_PIXELS = 800 * 480;

    // Сигнали керування модулями
    reg cmd_start;               // Запуск lcd_write_cmd
    reg cmd_data_start;          // Запуск lcd_write_cmd_data
    reg cmd_ndata_start;         // Запуск lcd_write_cmd_ndata
    wire cmd_done;               // Завершення lcd_write_cmd
    wire cmd_data_done;          // Завершення lcd_write_cmd_data
    wire cmd_ndata_done;         // Завершення lcd_write_cmd_ndata

    // Вихідні сигнали модулів
    wire [15:0] cmd_LCD_DATA, cmd_data_LCD_DATA, cmd_ndata_LCD_DATA;
    wire cmd_LCD_CS, cmd_LCD_RS, cmd_LCD_WR, cmd_LCD_RDX;
    wire cmd_data_LCD_CS, cmd_data_LCD_RS, cmd_data_LCD_WR, cmd_data_LCD_RDX;
    wire cmd_ndata_LCD_CS, cmd_ndata_LCD_RS, cmd_ndata_LCD_WR, cmd_ndata_LCD_RDX;

    // Вибір активного модуля
    reg [1:0] active_writer;     // 0 - none, 1 - cmd, 2 - cmd_data, 3 - cmd_ndata
    localparam WRITER_NONE = 2'd0, WRITER_CMD = 2'd1, WRITER_CMD_DATA = 2'd2, WRITER_CMD_NDATA = 2'd3;

    // Лічильник пікселів
    reg [31:0] pixel_cnt;

    // Інстанціювання модулів
    lcd_write_cmd cmd_writer (
        .clk(lcd_clk),
        .reset_n(reset_n),
        .start(cmd_start),
        .cmd(cmd_data),
        .LCD_CS(cmd_LCD_CS),
        .LCD_RS(cmd_LCD_RS),
        .LCD_WR(cmd_LCD_WR),
        .LCD_RDX(cmd_LCD_RDX),
        .LCD_DATA(cmd_LCD_DATA),
        .done(cmd_done)
    );

    lcd_write_cmd_data cmd_data_writer (
        .clk(lcd_clk),
        .reset_n(reset_n),
        .start(cmd_data_start),
        .cmd(cmd_data),
        .data(write_data),
        .LCD_CS(cmd_data_LCD_CS),
        .LCD_RS(cmd_data_LCD_RS),
        .LCD_WR(cmd_data_LCD_WR),
        .LCD_RDX(cmd_data_LCD_RDX),
        .LCD_DATA(cmd_data_LCD_DATA),
        .done(cmd_data_done)
    );

    lcd_write_cmd_ndata cmd_ndata_writer (
        .clk(lcd_clk),
        .reset_n(reset_n),
        .start(cmd_ndata_start),
        .cmd(16'h2C00), // Команда для запису пікселів
        .data(RED),    // Червоний колір
        .n(TOTAL_PIXELS),
        .LCD_CS(cmd_ndata_LCD_CS),
        .LCD_RS(cmd_ndata_LCD_RS),
        .LCD_WR(cmd_ndata_LCD_WR),
        .LCD_RDX(cmd_ndata_LCD_RDX),
        .LCD_DATA(cmd_ndata_LCD_DATA),
        .done(cmd_ndata_done)
    );

    // Мультиплексор для вибору вихідних сигналів
    always @(*) begin
        case (active_writer)
            WRITER_NONE: begin
                LCD_CS_reg = 1;
                LCD_RS_reg = 0;
                LCD_WR_reg = 1;
                LCD_RDX_reg = 1;
                LCD_DATA_reg = 16'bz;
                led_1_reg <= 1;
                led_2_reg <= 1;
            end
            WRITER_CMD: begin
                LCD_CS_reg = cmd_LCD_CS;
                LCD_RS_reg = cmd_LCD_RS;
                LCD_WR_reg = cmd_LCD_WR;
                LCD_RDX_reg = cmd_LCD_RDX;
                LCD_DATA_reg = cmd_LCD_DATA;
                led_1_reg <= 0;
                led_2_reg <= 0;
            end
            WRITER_CMD_DATA: begin
                LCD_CS_reg = cmd_data_LCD_CS;
                LCD_RS_reg = cmd_data_LCD_RS;
                LCD_WR_reg = cmd_data_LCD_WR;
                LCD_RDX_reg = cmd_data_LCD_RDX;
                LCD_DATA_reg = cmd_data_LCD_DATA;
                led_1_reg <= 0;
                led_2_reg <= 1;
            end
            WRITER_CMD_NDATA: begin
                LCD_CS_reg = cmd_ndata_LCD_CS;
                LCD_RS_reg = cmd_ndata_LCD_RS;
                LCD_WR_reg = cmd_ndata_LCD_WR;
                LCD_RDX_reg = cmd_ndata_LCD_RDX;
                LCD_DATA_reg = cmd_ndata_LCD_DATA;
                led_1_reg <= 1;
                led_2_reg <= 0;
            end
            default: begin
                LCD_CS_reg = 1;
                LCD_RS_reg = 0;
                LCD_WR_reg = 1;
                LCD_RDX_reg = 1;
                LCD_DATA_reg = 16'bz;
                led_1_reg <= 1;
                led_2_reg <= 1;
            end
        endcase
    end


    // Логіка FSM
    always @(posedge lcd_clk or negedge reset_n) begin
        if (!reset_n) begin
            state <= 0;
            pixel_cnt <= 0;
            LCD_RESET_reg <= 0;
            init_rom_addr <= 0;
            delay_counter <= 0;
            cmd_start <= 0;
            cmd_data_start <= 0;
            cmd_ndata_start <= 0;
            active_writer <= WRITER_NONE;
            cmd_data <= 0;
            write_data <= 0;
        end else begin
            case (state)
                0: begin // Очікування PLL
                    if (pll_locked) begin
                        LCD_RESET_reg <= 0;
                        LCD_BL_reg <= 1;
                        init_rom_addr <= 0;
                        delay_counter <= 2 * 8000; // 2 мс при 8 МГц
                        state <= 7;
                    end
                end
                7: begin // Затримка ресету
                    if (delay_counter > 0) begin
                        delay_counter <= delay_counter - 1;
                    end else begin
                        LCD_RESET_reg <= 1;
                        state <= 2;
                    end
                end
                2: begin // Ініціалізація з ROM
                    if (init_rom_addr <= 778) begin
                        if (!cmd_data_start) begin
                                cmd_data <= init_rom[init_rom_addr][15:0];
                                write_data <= init_rom[init_rom_addr + 1][15:0];
                                active_writer <= WRITER_CMD_DATA;
                                cmd_data_start <= 1;
                            end else if (cmd_data_done) begin
                                cmd_data_start <= 0;
                                active_writer <= WRITER_NONE;
                                init_rom_addr <= init_rom_addr + 2;
                            end
                        end
                     else begin
                        state <= 11;
                    end
                end
                11: begin // soft reset
                    if (!cmd_start) begin
                        cmd_data <= 16'h1100;
                        active_writer <= WRITER_CMD;
                        cmd_start <= 1;
                    end else if (cmd_done) begin
                        cmd_start <= 0;
                        active_writer <= WRITER_NONE;
                        delay_counter <= 120 * 8000; // 120 мс затримка
                        state <= 8;
                    end
                end
                8: begin // Затримка після ініціалізації
                    if (delay_counter > 0) begin
                        delay_counter <= delay_counter - 1;
                    end else begin
                        state <= 3;
                    end
                end
                3: begin // Увімкнення дисплея (команда 0x2900)
                    if (!cmd_start) begin
                        cmd_data <= 16'h2900;
                        active_writer <= WRITER_CMD;
                        cmd_start <= 1;
                    end else if (cmd_done) begin
                        cmd_start <= 0;
                        active_writer <= WRITER_NONE;
                        state <= 9;
                    end
                end
                9: begin // Перехід до наступного стану
                    state <= 4;
                end
                4: begin // Встановлення адреси (команда 0x2C00)
                    if (!cmd_start) begin
                        cmd_data <= 16'h2C00;
                        active_writer <= WRITER_CMD;
                        cmd_start <= 1;
                    end else if (cmd_done) begin
                        cmd_start <= 0;
                        active_writer <= WRITER_NONE;
                        state <= 10;
                    end
                end
                10: begin // Підготовка до заповнення пікселів
                    pixel_cnt <= 0;
                    state <= 5;
                end
                5: begin // Заповнення пікселів
                    if (!cmd_ndata_start) begin
                        active_writer <= WRITER_CMD_NDATA;
                        cmd_ndata_start <= 1;
                    end else if (cmd_ndata_done) begin
                        cmd_ndata_start <= 0;
                        active_writer <= WRITER_NONE;
                        state <= 6;
                    end
                end
                6: begin 

                end
                default: state <= 0;
            endcase
        end
    end

endmodule

