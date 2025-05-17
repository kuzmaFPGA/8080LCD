`ifndef CONSTANTS_V
`define CONSTANTS_V

localparam LCD_FREQ_MHZ = 62500;

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
           S_SET_DIR = 5'd22,
           S_FILL  = 5'd15,
           S_DISPLAY_ON = 5'd16,    // Увімкнення дисплея (0x2900)
           S_BACKLIGHT = 5'd17,     // Увімкнення підсвітки
           S_SET_ADDR = 5'd18,      // Встановлення адреси (0x2C00)
           S_PREP_FILL = 5'd19,     // Підготовка до заповнення пікселів
           S_FILL_PIXELS = 5'd20,   // Заповнення пікселів
           S_PAUSE = 5'd21;         // пауза

localparam  S_IDLE = 5'd0,
            
           S_SET_XSTART_H = 5'd2,  // Встановлення xStart високий байт (0x2A00)
           S_SET_XSTART_L = 5'd3,  // Встановлення xStart низький байт (0x2A01)
           S_SET_XEND_H = 5'd4,    // Встановлення xEnd високий байт (0x2A02)
           S_SET_XEND_L = 5'd5,    // Встановлення xEnd низький байт (0x2A03)
           S_SET_YSTART_H = 5'd6,  // Встановлення yStart високий байт (0x2B00)
           S_SET_YSTART_L = 5'd7,  // Встановлення yStart низький байт (0x2B01)
           S_SET_YEND_H = 5'd8,    // Встановлення yEnd високий байт (0x2B02)
           S_SET_YEND_L = 5'd9;    // Встановлення yEnd низький байт (0x2B03)

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

// Оголошення перелічення для типів writer
localparam WRITER_NONE = 3'd0,
           WRITER_CMD = 3'd1,
           WRITER_CMD_DATA = 3'd2,
           WRITER_CMD_NDATA = 3'd3,
           WRITER_READ = 3'd4;
           
`endif