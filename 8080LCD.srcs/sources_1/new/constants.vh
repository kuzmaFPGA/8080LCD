`ifndef CONSTANTS_V
`define CONSTANTS_V

// Частота LCD (у кГц)
parameter LCD_FREQ_MHZ = 6250;

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
    WRITER_NONE,
    WRITER_CMD,
    WRITER_CMD_DATA,
    WRITER_CMD_NDATA,
    WRITER_READ
} writer_t;

`endif