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
    output    [4:0]  la_out
);
localparam LCD_FREQ_MHZ = 62500;
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

// ROM ініціалізації
reg [15:0] init_rom [0:779]; // 780 рядків
initial $readmemh("init.mem", init_rom);
reg [9:0] init_rom_addr;     // Лічильник адреси

// Дані та тип для запису
reg [15:0] cmd_data;         // Команда
reg [15:0] write_data;       // Дані для модуля cmd_data

// Визначення текстових станів
localparam S_INIT = 5'd0,           // Очікування PLL
           S_RESET_LOW = 5'd1,      // Низький рівень ресету (100 мс)
           S_RESET_HIGH = 5'd2,     // Високий рівень ресету (50 мс)
           S_ROM_INIT = 5'd3,       // Ініціалізація з ROM
           S_READ_ID_PAGE = 5'd4,   // Налаштування сторінки для читання ID (0xF000)
           S_READ_ID_F001 = 5'd5,   // Налаштування 0xF001
           S_READ_ID_F002 = 5'd6,   // Налаштування 0xF002
           S_READ_ID_F003 = 5'd7,   // Налаштування 0xF003
           S_READ_ID_F004 = 5'd8,   // Налаштування 0xF004
           S_READ_ID_C500 = 5'd9,   // Читання ID (0xC500)
           S_READ_ID_BYTE1 = 5'd10, // Читання першого байта ID
           S_READ_ID_C501 = 5'd11,  // Читання другого байта ID (0xC501)
           S_READ_ID_BYTE2 = 5'd12, // Читання другого байта ID
           S_SOFT_RESET = 5'd13,    // Soft reset (0x1100)
           S_DELAY = 5'd14,         // Затримка після ініціалізації (120 мс)
           S_SET_DIR = 5'd15,       // Встановлення напрямку (0x3600)
           S_SET_XSTART_H = 5'd16,  // Встановлення xStart високий байт (0x2A00)
           S_SET_XSTART_L = 5'd17,  // Встановлення xStart низький байт (0x2A01)
           S_SET_XEND_H = 5'd18,    // Встановлення xEnd високий байт (0x2A02)
           S_SET_XEND_L = 5'd19,    // Встановлення xEnd низький байт (0x2A03)
           S_SET_YSTART_H = 5'd20,  // Встановлення yStart високий байт (0x2B00)
           S_SET_YSTART_L = 5'd21,  // Встановлення yStart низький байт (0x2B01)
           S_SET_YEND_H = 5'd22,    // Встановлення yEnd високий байт (0x2B02)
           S_SET_YEND_L = 5'd23,    // Встановлення yEnd низький байт (0x2B03)
           S_DISPLAY_ON = 5'd24,    // Увімкнення дисплея (0x2900)
           S_BACKLIGHT = 5'd25,     // Увімкнення підсвітки
           S_SET_ADDR = 5'd26,      // Встановлення адреси (0x2C00)
           S_PREP_FILL = 5'd27,     // Підготовка до заповнення пікселів
           S_FILL_PIXELS = 5'd28,   // Заповнення пікселів
           S_LOOP = 5'd29,          // Повторне заповнення
           S_PAUSE = 5'd30;         // пауза

// Станова машина
reg [4:0] state;             // 5 біт для підтримки всіх станів
assign la_out = state;
// Лічильник затримок
reg [31:0] delay_counter;

// Константи кольорів (RGB565)
parameter WHITE = 16'hFFFF;
parameter BLACK = 16'h0000; 
parameter BLUE = 16'h001F; 
parameter BRED = 16'hF81F;
parameter GRED 	= 16'hFFE0;
parameter GBLUE = 16'h07FF;
parameter RED = 16'hF800;
parameter MAGENTA = 16'hF81F;
parameter GREEN = 16'h07E0;
parameter CYAN = 16'h7FFF;
parameter YELLOW = 16'hFFE0;
parameter BROWN = 16'hBC40; 
parameter BRRED = 16'hFC07;
parameter GRAY = 16'h8430; 

parameter DARKBLUE = 16'h01CF;	
parameter LIGHTBLUE = 16'h7D7C; 
parameter GRAYBLUE = 16'h5458; 

parameter LIGHTGREEN = 16'h841F; 
parameter LIGHTGRAY = 16'hEF5B; 
parameter LGRAY = 16'hC618; 

parameter LGRAYBLUE = 16'hA651; 
parameter LBBLUE = 16'h2B12;

// Загальна кількість пікселів для 800x480 дисплея
parameter TOTAL_PIXELS = 800 * 480;

// Координати для області заповнення
parameter X_START = 0;
parameter X_END = 480 - 1;
parameter Y_START = 0;
parameter Y_END = 800 - 1;

// Сигнали керування модулями
reg cmd_start;               // Запуск lcd_write_cmd
reg cmd_data_start;          // Запуск lcd_write_cmd_data
reg cmd_ndata_start;         // Запуск lcd_write_cmd_ndata
wire cmd_done;               // Завершення lcd_write_cmd
wire cmd_data_done;          // Завершення lcd_write_cmd_data
wire cmd_ndata_done;         // Завершення lcd_write_cmd_ndata

// Сигнали для мультиплексора
wire [15:0] cmd_LCD_DATA, cmd_data_LCD_DATA, cmd_ndata_LCD_DATA, cmd_read_LCD_DATA;
wire cmd_LCD_CS, cmd_data_LCD_CS, cmd_ndata_LCD_CS, cmd_read_LCD_CS;
wire cmd_LCD_RS, cmd_data_LCD_RS, cmd_ndata_LCD_RS, cmd_read_LCD_RS;
wire cmd_LCD_WR, cmd_data_LCD_WR, cmd_ndata_LCD_WR, cmd_read_LCD_WR;
wire cmd_LCD_RDX, cmd_data_LCD_RDX, cmd_ndata_LCD_RDX, cmd_read_LCD_RDX;

// Вибір активного модуля
reg [2:0] active_writer;     // 0 - none, 1 - cmd, 2 - cmd_data, 3 - cmd_ndata, 4 - read
// Оголошення перелічення для типів writer
localparam WRITER_NONE = 3'd0,
           WRITER_CMD = 3'd1,
           WRITER_CMD_DATA = 3'd2,
           WRITER_CMD_NDATA = 3'd3,
           WRITER_READ = 3'd4;

// Лічильник пікселів
reg [31:0] pixel_cnt;


// Інстанціювання модулів

keypad_4x4 keyboard (
    .clk(clk),             // Тактовий сигнал
    .rst_n(reset_n),       // Сигнал скидання (активний низький)
    .col(col),             // Стовпці (A12, B11, D10, D9)
    .row(row),             // Рядки (D14, D13, C12, E13)
    .key_code(key_code),   // Код натиснутої клавіші
    .key_valid(led_1)      // Сигнал, що клавіша натиснута
);


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
reg [15:0] fillcolor;
lcd_write_cmd_ndata cmd_ndata_writer (
    .clk(lcd_clk),
    .reset_n(reset_n),
    .start(cmd_ndata_start),
    .cmd(16'h2C00), // Команда для запису пікселів
    .data(fillcolor),     // Червоний колір
    .n(TOTAL_PIXELS),
    .LCD_CS(cmd_ndata_LCD_CS),
    .LCD_RS(cmd_ndata_LCD_RS),
    .LCD_WR(cmd_ndata_LCD_WR),
    .LCD_RDX(cmd_ndata_LCD_RDX),
    .LCD_DATA(cmd_ndata_LCD_DATA),
    .done(cmd_ndata_done)
);

reg read_start;
wire read_done;
wire [15:0] read_data;
reg [15:0] lcd_id;

lcd_read_data read_writer (
    .clk(lcd_clk),
    .reset_n(reset_n),
    .start(read_start),
    .data(read_data),
    .done(read_done),
    .LCD_CS(cmd_read_LCD_CS),
    .LCD_RS(cmd_read_LCD_RS),
    .LCD_WR(cmd_read_LCD_WR),
    .LCD_RDX(cmd_read_LCD_RDX),
    .LCD_DATA(LCD_DATA)
);

// Мультиплексор для вибору сигналів
always @(*) begin
    case (active_writer)
        WRITER_NONE: begin
            LCD_CS_reg = 1;
            LCD_RS_reg = 0;
            LCD_WR_reg = 1;
            LCD_RDX_reg = 1;
            LCD_DATA_reg = 16'h0000;
        end
        WRITER_CMD: begin
            LCD_CS_reg = cmd_LCD_CS;
            LCD_RS_reg = cmd_LCD_RS;
            LCD_WR_reg = cmd_LCD_WR;
            LCD_RDX_reg = cmd_LCD_RDX;
            LCD_DATA_reg = cmd_LCD_DATA;
        end
        WRITER_CMD_DATA: begin
            LCD_CS_reg = cmd_data_LCD_CS;
            LCD_RS_reg = cmd_data_LCD_RS;
            LCD_WR_reg = cmd_data_LCD_WR;
            LCD_RDX_reg = cmd_data_LCD_RDX;
            LCD_DATA_reg = cmd_data_LCD_DATA;
        end
        WRITER_CMD_NDATA: begin
            LCD_CS_reg = cmd_ndata_LCD_CS;
            LCD_RS_reg = cmd_ndata_LCD_RS;
            LCD_WR_reg = cmd_ndata_LCD_WR;
            LCD_RDX_reg = cmd_ndata_LCD_RDX;
            LCD_DATA_reg = cmd_ndata_LCD_DATA;
        end
        WRITER_READ: begin
            LCD_CS_reg = cmd_read_LCD_CS;
            LCD_RS_reg = cmd_read_LCD_RS;
            LCD_WR_reg = cmd_read_LCD_WR;
            LCD_RDX_reg = cmd_read_LCD_RDX;
            LCD_DATA_reg = 16'hZZZZ; // Високий імпеданс для читання
        end
        default: begin
            LCD_CS_reg = 1;
            LCD_RS_reg = 0;
            LCD_WR_reg = 1;
            LCD_RDX_reg = 1;
            LCD_DATA_reg = 16'hzzzz;
        end
    endcase
end

// Логіка FSM
always @(posedge lcd_clk or negedge reset_n) begin
    if (!reset_n) begin
        state <= S_INIT;
        pixel_cnt <= 0;
        LCD_RESET_reg <= 0;
        LCD_BL_reg <= 0;
        init_rom_addr <= 0;
        delay_counter <= 0;
        cmd_start <= 0;
        cmd_data_start <= 0;
        cmd_ndata_start <= 0;
        active_writer <= WRITER_NONE;
        cmd_data <= 0;
        write_data <= 0;
        read_start <= 0;
        lcd_id <= 0;
    end else begin
        case (state)
            S_INIT: begin // Очікування PLL
                if (pll_locked) begin
                    LCD_RESET_reg <= 0;
                    init_rom_addr <= 0;
                    delay_counter <= 100 * LCD_FREQ_MHZ; // 100 мс при 8 МГц
                    state <= S_RESET_LOW;
                end
            end
            S_RESET_LOW: begin // Низький рівень ресету
                if (delay_counter > 0) begin
                    delay_counter <= delay_counter - 1;
                end else begin
                    LCD_RESET_reg <= 1;
                    delay_counter <= 50 * LCD_FREQ_MHZ; // 50 мс
                    state <= S_RESET_HIGH;
                end
            end
            S_RESET_HIGH: begin // Високий рівень ресету
                if (delay_counter > 0) begin
                    delay_counter <= delay_counter - 1;
                end else begin
                    state <= S_ROM_INIT;
                end
            end
            S_ROM_INIT: begin // Ініціалізація з ROM
                if (init_rom_addr <= 778) begin
                    if (!cmd_data_start) begin
                        cmd_data <= init_rom[init_rom_addr];
                        write_data <= init_rom[init_rom_addr + 1];
                        active_writer <= WRITER_CMD_DATA;
                        cmd_data_start <= 1;
                    end else if (cmd_data_done) begin
                        cmd_data_start <= 0;
                        active_writer <= WRITER_NONE;
                        init_rom_addr <= init_rom_addr + 2;
                    end
                end else begin
                    state <= S_SOFT_RESET;//S_READ_ID_PAGE;
                end
            end
            S_READ_ID_PAGE: begin // Налаштування сторінки для читання ID
                if (!cmd_data_start) begin
                    cmd_data <= 16'hF000;
                    write_data <= 16'h55;
                    active_writer <= WRITER_CMD_DATA;
                    cmd_data_start <= 1;
                end else if (cmd_data_done) begin
                    cmd_data_start <= 0;
                    active_writer <= WRITER_NONE;
                    state <= S_READ_ID_F001;
                end
            end
            S_READ_ID_F001: begin
                if (!cmd_data_start) begin
                    cmd_data <= 16'hF001;
                    write_data <= 16'hAA;
                    active_writer <= WRITER_CMD_DATA;
                    cmd_data_start <= 1;
                end else if (cmd_data_done) begin
                    cmd_data_start <= 0;
                    active_writer <= WRITER_NONE;
                    state <= S_READ_ID_F002;
                end
            end
            S_READ_ID_F002: begin
                if (!cmd_data_start) begin
                    cmd_data <= 16'hF002;
                    write_data <= 16'h52;
                    active_writer <= WRITER_CMD_DATA;
                    cmd_data_start <= 1;
                end else if (cmd_data_done) begin
                    cmd_data_start <= 0;
                    active_writer <= WRITER_NONE;
                    state <= S_READ_ID_F003;
                end
            end
            S_READ_ID_F003: begin
                if (!cmd_data_start) begin
                    cmd_data <= 16'hF003;
                    write_data <= 16'h08;
                    active_writer <= WRITER_CMD_DATA;
                    cmd_data_start <= 1;
                end else if (cmd_data_done) begin
                    cmd_data_start <= 0;
                    active_writer <= WRITER_NONE;
                    state <= S_READ_ID_F004;
                end
            end
            S_READ_ID_F004: begin
                if (!cmd_data_start) begin
                    cmd_data <= 16'hF004;
                    write_data <= 16'h01;
                    active_writer <= WRITER_CMD_DATA;
                    cmd_data_start <= 1;
                end else if (cmd_data_done) begin
                    cmd_data_start <= 0;
                    active_writer <= WRITER_NONE;
                    state <= S_READ_ID_C500;
                end
            end
            S_READ_ID_C500: begin // Читання ID (0xC500)
                if (!cmd_start) begin
                    cmd_data <= 16'hC500;
                    active_writer <= WRITER_CMD;
                    cmd_start <= 1;
                end else if (cmd_done) begin
                    cmd_start <= 0;
                    active_writer <= WRITER_NONE;
                    state <= S_READ_ID_BYTE1;
                end
            end
            S_READ_ID_BYTE1: begin // Читання першого байта ID
                if (!read_start) begin
                    active_writer <= WRITER_READ;
                    read_start <= 1;
                end else if (read_done) begin
                    read_start <= 0;
                    lcd_id[15:8] <= read_data;
                    active_writer <= WRITER_NONE;
                    state <= S_READ_ID_C501;
                end
            end
            S_READ_ID_C501: begin // Читання другого байта ID (0xC501)
                if (!cmd_start) begin
                    cmd_data <= 16'hC501;
                    active_writer <= WRITER_CMD;
                    cmd_start <= 1;
                end else if (cmd_done) begin
                    cmd_start <= 0;
                    active_writer <= WRITER_NONE;
                    state <= S_READ_ID_BYTE2;
                end
            end
            S_READ_ID_BYTE2: begin // Читання другого байта ID
                if (!read_start) begin
                    active_writer <= WRITER_READ;
                    read_start <= 1;
                end else if (read_done) begin
                    read_start <= 0;
                    lcd_id[7:0] <= read_data;
                    active_writer <= WRITER_NONE;
                    state <= S_SOFT_RESET;
                end
            end
            S_SOFT_RESET: begin // Soft reset
                if (!cmd_start) begin
                    cmd_data <= 16'h1100;
                    active_writer <= WRITER_CMD;
                    cmd_start <= 1;
                end else if (cmd_done) begin
                    cmd_start <= 0;
                    active_writer <= WRITER_NONE;
                    delay_counter <= 120 * LCD_FREQ_MHZ; // 120 мс затримка
                    state <= S_DELAY;
                end
            end
            S_DELAY: begin // Затримка після ініціалізації
                if (delay_counter > 0) begin
                    delay_counter <= delay_counter - 1;
                end else begin
                    state <= S_SET_DIR;
                end
            end
            S_SET_DIR: begin // Встановлення напрямку (0x3600, 0x00)
                if (!cmd_data_start) begin
                    cmd_data <= 16'h3600;
                    write_data <= 16'h00; //(1<<5)|(1<<6); 
                    active_writer <= WRITER_CMD_DATA;
                    cmd_data_start <= 1;
                end else if (cmd_data_done) begin
                    cmd_data_start <= 0;
                    active_writer <= WRITER_NONE;
                    state <= S_SET_XSTART_H;
                end
            end
            S_SET_XSTART_H: begin // Встановлення xStart (0x2A00, xStart >> 8)
                if (!cmd_data_start) begin
                    cmd_data <= 16'h2A00;
                    write_data <= (X_START >> 8); // 0x00
                    active_writer <= WRITER_CMD_DATA;
                    cmd_data_start <= 1;
                end else if (cmd_data_done) begin
                    cmd_data_start <= 0;
                    active_writer <= WRITER_NONE;
                    state <= S_SET_XSTART_L;
                end
            end
            S_SET_XSTART_L: begin // Встановлення xStart (0x2A01, xStart & 0xFF)
                if (!cmd_data_start) begin
                    cmd_data <= 16'h2A01;
                    write_data <= (X_START & 16'hFF); // 0x00
                    active_writer <= WRITER_CMD_DATA;
                    cmd_data_start <= 1;
                end else if (cmd_data_done) begin
                    cmd_data_start <= 0;
                    active_writer <= WRITER_NONE;
                    state <= S_SET_XEND_H;
                end
            end
            S_SET_XEND_H: begin // Встановлення xEnd (0x2A02, xEnd >> 8)
                if (!cmd_data_start) begin
                    cmd_data <= 16'h2A02;
                    write_data <= (X_END >> 8); // 0x03
                    active_writer <= WRITER_CMD_DATA;
                    cmd_data_start <= 1;
                end else if (cmd_data_done) begin
                    cmd_data_start <= 0;
                    active_writer <= WRITER_NONE;
                    state <= S_SET_XEND_L;
                end
            end
            S_SET_XEND_L: begin // Встановлення xEnd (0x2A03, xEnd & 0xFF)
                if (!cmd_data_start) begin
                    cmd_data <= 16'h2A03;
                    write_data <= (X_END & 16'hFF); // 0x1F
                    active_writer <= WRITER_CMD_DATA;
                    cmd_data_start <= 1;
                end else if (cmd_data_done) begin
                    cmd_data_start <= 0;
                    active_writer <= WRITER_NONE;
                    state <= S_SET_YSTART_H;
                end
            end
            S_SET_YSTART_H: begin // Встановлення yStart (0x2B00, yStart >> 8)
                if (!cmd_data_start) begin
                    cmd_data <= 16'h2B00;
                    write_data <= (Y_START >> 8); // 0x00
                    active_writer <= WRITER_CMD_DATA;
                    cmd_data_start <= 1;
                end else if (cmd_data_done) begin
                    cmd_data_start <= 0;
                    active_writer <= WRITER_NONE;
                    state <= S_SET_YSTART_L;
                end
            end
            S_SET_YSTART_L: begin // Встановлення yStart (0x2B01, yStart & 0xFF)
                if (!cmd_data_start) begin
                    cmd_data <= 16'h2B01;
                    write_data <= (Y_START & 16'hFF); // 0x00
                    active_writer <= WRITER_CMD_DATA;
                    cmd_data_start <= 1;
                end else if (cmd_data_done) begin
                    cmd_data_start <= 0;
                    active_writer <= WRITER_NONE;
                    state <= S_SET_YEND_H;
                end
            end
            S_SET_YEND_H: begin // Встановлення yEnd (0x2B02, yEnd >> 8)
                if (!cmd_data_start) begin
                    cmd_data <= 16'h2B02;
                    write_data <= (Y_END >> 8); // 0x01
                    active_writer <= WRITER_CMD_DATA;
                    cmd_data_start <= 1;
                end else if (cmd_data_done) begin
                    cmd_data_start <= 0;
                    active_writer <= WRITER_NONE;
                    state <= S_SET_YEND_L;
                end
            end
            S_SET_YEND_L: begin // Встановлення yEnd (0x2B03, yEnd & 0xFF)
                if (!cmd_data_start) begin
                    cmd_data <= 16'h2B03;
                    write_data <= (Y_END & 16'hFF); // 0xDF
                    active_writer <= WRITER_CMD_DATA;
                    cmd_data_start <= 1;
                end else if (cmd_data_done) begin
                    cmd_data_start <= 0;
                    active_writer <= WRITER_NONE;
                    state <= S_DISPLAY_ON;
                end
            end
            S_DISPLAY_ON: begin // Увімкнення дисплея (команда 0x2900)
                if (!cmd_start) begin
                    cmd_data <= 16'h2900;
                    active_writer <= WRITER_CMD;
                    cmd_start <= 1;
                end else if (cmd_done) begin
                    cmd_start <= 0;
                    LCD_BL_reg <= 1; // Увімкнення підсвітки
                    active_writer <= WRITER_NONE;
                    state <= S_BACKLIGHT;
                end
            end
            S_BACKLIGHT: begin // Увімкнення підсвітки
                state <= S_SET_ADDR;
                fillcolor <= GREEN;
            end
            S_SET_ADDR: begin // Встановлення адреси (команда 0x2C00)
                if (!cmd_start) begin
                    cmd_data <= 16'h2C00;
                    active_writer <= WRITER_CMD;
                    cmd_start <= 1;
                end else if (cmd_done) begin
                    cmd_start <= 0;
                    active_writer <= WRITER_NONE;
                    state <= S_PREP_FILL;
                end
            end
            S_PREP_FILL: begin // Підготовка до заповнення пікселів
                pixel_cnt <= 0;
                state <= S_FILL_PIXELS;
            end
            S_FILL_PIXELS: begin // Заповнення пікселів
                if (!cmd_ndata_start) begin
                    active_writer <= WRITER_CMD_NDATA;
                    cmd_ndata_start <= 1;
                end else if (cmd_ndata_done) begin
                    cmd_ndata_start <= 0;
                    active_writer <= WRITER_NONE;
                    delay_counter <= 1000 * LCD_FREQ_MHZ; // 1 с затримка
                    state <= S_PAUSE;
                end
            end
            S_PAUSE : begin
                if (delay_counter > 0) begin
                    delay_counter <= delay_counter - 1;
                end else begin
                    state <= S_LOOP;
                end
            end
            S_LOOP: begin // Повторне заповнення
                fillcolor <= GRAY;
                state <= S_SET_ADDR;
            end
            default: state <= S_INIT;
        endcase
    end
end

endmodule