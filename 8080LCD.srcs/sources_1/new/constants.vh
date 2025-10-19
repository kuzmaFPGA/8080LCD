`ifndef CONSTANTS_V
`define CONSTANTS_V

// Частота LCD (у кГц)
parameter LCD_FREQ_KHZ = 50000;//62500;
parameter SYS_CLK_FREQ_MHZ = 50; // Частота системного годинника у МГц
parameter SYS_CLK_FREQ_KHZ = 50000;
parameter MAIN_CLK_FREQ_KHZ = 10000;

parameter DELAY_1S = 1000 * LCD_FREQ_KHZ;  // Real 1-second delay based on clock freq
parameter DELAY_TRIGGER = 10;     // Real short delay (adjust as needed)
parameter DELAY_50_MS = 50 * LCD_FREQ_KHZ;        
parameter DELAY_100_MS = 100 * LCD_FREQ_KHZ;      
parameter DELAY_120_MS = 120 * LCD_FREQ_KHZ; 

// ✅ Частота оновлення екрану
parameter SCREEN_REFRESH_HZ = 60; // 60 Гц
parameter SCREEN_REFRESH_TICKS = (SYS_CLK_FREQ_MHZ * 1_000_000) / SCREEN_REFRESH_HZ; // 833,500 для 60 Гц

// ✅ Розміри дисплея: 800x480
parameter DISPLAY_WIDTH = 800;   // X (ширина)
parameter DISPLAY_HEIGH = 480;   // Y (висота)

// ✅ ТОЧНІ розміри шрифтів
parameter DIGIT_WIDTH = 64;      // Цифри
parameter DIGIT_HEIGHT = 128;
parameter CHAR_WIDTH = 39;       // ✅ Букви
parameter CHAR_HEIGHT = 64;
parameter ARROW_WIDTH = 63;     // ✅ Стрілки
parameter ARROW_HEIGHT = 64;

// Константи кольорів (RGB565)
parameter WHITE = 16'hFFFF;
parameter BLACK = 16'h0000; 
parameter BLUE = 16'h001F; 
parameter BRED = 16'hF81F;
parameter GRED = 16'hFFE0;
parameter GBLUE = 16'h07FF;
parameter RED = 16'hF800;
parameter MAGENTA = 16'hF81F;
parameter GREEN = 16'h07E0;
parameter CYAN = 16'h7FFF;
parameter YELLOW = 16'hFFE0;
parameter BROWN = 16'hBC40; 
parameter BRRED = 16'hFC07;
parameter GRAY = 16'h8430; 
parameter DARKBLUE = 16'b1010101010101010;	
parameter LIGHTBLUE = 16'h7D7C; 
parameter GRAYBLUE = 16'h5458; 
parameter LIGHTGREEN = 16'h841F; 
parameter LIGHTGRAY = 16'hEF5B; 
parameter LGRAY = 16'hC618; 
parameter LGRAYBLUE = 16'hA651; 
parameter LBBLUE = 16'h2B12;

parameter TOTAL_PIXELS = DISPLAY_WIDTH * DISPLAY_HEIGH; // 384000

parameter X_START = 0;
parameter X_END = DISPLAY_WIDTH - 1;   // 799
parameter Y_START = 0;
parameter Y_END = DISPLAY_HEIGH - 1;   // 479
// Перерахування для станів основної машини стану
typedef enum logic [4:0] {
    S_INIT = 0,           // Wait for PLL
    S_RESET_LOW = 1,      // Low reset (100 ms)
    S_RESET_HIGH =2,     // High reset (50 ms)
    S_ROM_INIT =3,       // ROM initialization
    S_SOFT_RESET =4,     // Soft reset (0x1100)
    S_DELAY =5,          // Delay after initialization (120 ms)
    S_SET_DIR= 6,        // Set direction (0x3600)
    S_FILL=7,           // Fill screen
    S_BACKLIGHT=8,       // Backlight on
    S_IDLE = 9,
    S_SET_XSTART_H = 10,   // Set xStart high byte (0x2A00)
    S_SET_XSTART_L = 11,   // Set xStart low byte (0x2A01)
    S_SET_XEND_H =12 ,     // Set xEnd high byte (0x2A02)
    S_SET_XEND_L = 13,     // Set xEnd low byte (0x2A03)
    S_SET_YSTART_H = 14,   // Set yStart high byte (0x2B00)
    S_SET_YSTART_L = 15,   // Set yStart low byte (0x2B01)
    S_SET_YEND_H =16,     // Set yEnd high byte (0x2B02)
    S_SET_YEND_L =17,     // Set yEnd low byte (0x2B03)
    S_DISPLAY_ON = 18,     // Enable display (0x2900)
    S_SET_ADDR = 19,       // Set address (0x2C00)
    S_PREP_FILL =20,      // Prepare for pixel fill
    S_FILL_PIXELS = 21,    // Fill pixels
    S_PAUSE=22           // Pause
} state_t;


// Перерахування для типів writer
typedef enum logic [2:0] {
    WRITER_NONE  = 0,
    WRITER_CMD = 1,
    WRITER_CMD_DATA = 3,
    WRITER_CMD_NDATA = 4,
    WRITER_READ = 5
} writer_t;


parameter TEXT_COLOR = YELLOW;
parameter TEXT_BACK_COLOR = BLUE;

// ✅ BRAM адреси
parameter CHAR_BASE = DIGIT_HEIGHT * DIGIT_WIDTH * 10 + 1; // Після 10 цифр
parameter ARROW_BASE = CHAR_BASE + 8 * CHAR_WIDTH * CHAR_HEIGHT + 1; // Після 8 букв

// ✅ Відступ між буквами (адаптовано під 78px)
parameter CHAR_SPACING = 0;     // Малий відступ для щільності

// ✅ СТРІЛКИ (над/під цифрами)
parameter ARROW_X_OFFSET = 0;   // Центр по X
parameter ARROW_Y_OFFSET = 16;  // Відступ від рамки

// ✅ КООРДИНАТИ КНОПОК 
parameter BUTTON_X_EDIT_START = 10;
parameter BUTTON_X_EDIT_END = BUTTON_X_EDIT_START + 4 * CHAR_WIDTH + 3 * CHAR_SPACING;
parameter BUTTON_X_SAVE_START = 400;
parameter BUTTON_X_SAVE_END = BUTTON_X_SAVE_START + 4 * CHAR_WIDTH + 3 * CHAR_SPACING;
parameter BUTTON_Y_TOP = DISPLAY_HEIGH - CHAR_HEIGHT - 10;
parameter BUTTON_Y_BOTTOM = BUTTON_Y_TOP + CHAR_HEIGHT;

// ✅ ПОЗИЦІЯ ЦИФР 
parameter DIGIT_Y = ARROW_HEIGHT + ARROW_Y_OFFSET + 20;
parameter DIGIT_X_START_COORD = 80;
parameter DIGIT_SPACING = 12;
parameter [31:0] DIGIT_X_START [0:4] = '{DIGIT_X_START_COORD,  
                                         DIGIT_X_START_COORD + 1 * (DIGIT_SPACING + DIGIT_WIDTH),  
                                         DIGIT_X_START_COORD + 2 * (DIGIT_SPACING + DIGIT_WIDTH), 
                                         DIGIT_X_START_COORD + 3 * (DIGIT_SPACING + DIGIT_WIDTH), 
                                         DIGIT_X_START_COORD + 4 * (DIGIT_SPACING + DIGIT_WIDTH)}; // Starting x-coordinate for each digit

// ✅ РАМИ для цифр
parameter FRAME_THICK = 1;
parameter FRAME_Y_TOP = DIGIT_Y;
parameter FRAME_Y_BOTTOM = DIGIT_Y + DIGIT_HEIGHT -1 ;
parameter FRAME_COLOR = RED;
`endif