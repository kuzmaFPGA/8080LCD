`ifndef CONSTANTS_V
`define CONSTANTS_V

// Частота LCD (у кГц)
parameter LCD_FREQ_KHZ = 50000; // 62500;
parameter SYS_CLK_FREQ_MHZ = 50; // Частота системного годинника у МГц
parameter SYS_CLK_FREQ_KHZ = 50000;
parameter MAIN_CLK_FREQ_KHZ = 10000;

parameter DELAY_1S = 1000 * LCD_FREQ_KHZ;  // Real 1-second delay based on clock freq
parameter DELAY_TRIGGER = 10;     // Real short delay (adjust as needed)
parameter DELAY_50_MS = 50 * LCD_FREQ_KHZ;        
parameter DELAY_100_MS = 100 * LCD_FREQ_KHZ;      
parameter DELAY_120_MS = 120 * LCD_FREQ_KHZ; 

parameter DISPLAY_WIDTH = 800;
parameter DISPLAY_HEIGHT = 480; // Fixed typo from DISPLAY_HEIGH
parameter TEXT_WIDTH = 64;
parameter TEXT_HEIGHT = 128; // Fixed typo from TEXT_HEIGH

parameter DIGIT_HEIGHT = 128;
parameter DIGIT_WIDTH = 64;

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

// Загальна кількість пікселів для 800x480 дисплея
parameter TOTAL_PIXELS = DISPLAY_WIDTH * DISPLAY_HEIGHT;

// Координати для області заповнення
parameter X_START = 0;
parameter X_END = DISPLAY_HEIGHT - 1;
parameter Y_START = 0;
parameter Y_END = DISPLAY_WIDTH - 1;

// Перерахування для станів основної машини стану
typedef enum logic [4:0] {
    S_INIT = 0,           // Wait for PLL
    S_RESET_LOW = 1,      // Low reset (100 ms)
    S_RESET_HIGH = 2,     // High reset (50 ms)
    S_ROM_INIT = 3,       // ROM initialization
    S_SOFT_RESET = 4,     // Soft reset (0x1100)
    S_DELAY = 5,          // Delay after initialization (120 ms)
    S_SET_DIR = 6,        // Set direction (0x3600)
    S_FILL = 7,           // Fill screen
    S_BACKLIGHT = 8,      // Backlight on
    S_IDLE = 9,
    S_SET_XSTART_H = 10,  // Set xStart high byte (0x2A00)
    S_SET_XSTART_L = 11,  // Set xStart low byte (0x2A01)
    S_SET_XEND_H = 12,    // Set xEnd high byte (0x2A02)
    S_SET_XEND_L = 13,    // Set xEnd low byte (0x2A03)
    S_SET_YSTART_H = 14,  // Set yStart high byte (0x2B00)
    S_SET_YSTART_L = 15,  // Set yStart low byte (0x2B01)
    S_SET_YEND_H = 16,    // Set yEnd high byte (0x2B02)
    S_SET_YEND_L = 17,    // Set yEnd low byte (0x2B03)
    S_DISPLAY_ON = 18,    // Enable display (0x2900)
    S_SET_ADDR = 19,      // Set address (0x2C00)
    S_PREP_FILL = 20,     // Prepare for pixel fill
    S_FILL_PIXELS = 21,   // Fill pixels
    S_PAUSE = 22          // Pause
} state_t;

// Перерахування для типів writer
typedef enum logic [2:0] {
    WRITER_NONE = 0,
    WRITER_CMD = 1,
    WRITER_CMD_DATA = 3,
    WRITER_CMD_NDATA = 4,
    WRITER_READ = 5
} writer_t;

parameter TEXT_COLOR = RED;
parameter TEXT_BACK_COLOR = WHITE;
parameter DIGIT_Y = 400;
parameter DIGIT_X_BASE = 80; // Base x-coordinate for first digit
parameter DIGIT_SPACING = DIGIT_WIDTH; // Spacing between digits
parameter CHAR_BASE = DIGIT_HEIGHT * DIGIT_WIDTH * 10;
parameter CHAR_WIDTH = 64;
parameter CHAR_HEIGHT = 128;
parameter EDIT_X = 600;
parameter BUTTON_Y = 130;
parameter SAVE_X = 100;
parameter FRAME_THICK = 4;
parameter ARROW_BASE = CHAR_BASE + CHAR_WIDTH * CHAR_HEIGHT * 8; // After letters
parameter ARROW_WIDTH = 64;
parameter ARROW_HEIGHT = 128;
parameter ARROW_X_OFFSET = 0;
parameter ARROW_Y_UP = DIGIT_Y - ARROW_HEIGHT; // Up arrow above digits
parameter ARROW_Y_DOWN = DIGIT_Y + DIGIT_HEIGHT; // Down arrow below digits
parameter FRAME_Y_TOP = DIGIT_Y - FRAME_THICK; // Top frame above digits
parameter FRAME_Y_BOTTOM = DIGIT_Y + DIGIT_HEIGHT; // Bottom frame below digits
parameter EDIT_BUTTON_X_START = 40; // Edit button x start
parameter EDIT_BUTTON_X_END = 168; // Edit button x end
parameter SAVE_BUTTON_X_START = 280; // Save button x start
parameter SAVE_BUTTON_X_END = 408; // Save button x end
parameter BUTTON_Y_END = BUTTON_Y + CHAR_HEIGHT; // Button y end

`endif