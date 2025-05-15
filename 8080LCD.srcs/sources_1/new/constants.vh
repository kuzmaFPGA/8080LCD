`ifndef CONSTANTS_V
`define CONSTANTS_V

// Частота LCD (МГц)
`define LCD_FREQ_MHZ 62500

// Константи кольорів (RGB565)
`define WHITE       16'hFFFF
`define BLACK       16'h0000
`define BLUE        16'h001F
`define BRED        16'hF81F
`define GRED        16'hFFE0
`define GBLUE       16'h07FF
`define RED         16'hF800
`define MAGENTA     16'hF81F
`define GREEN       16'h07E0
`define CYAN        16'h7FFF
`define YELLOW      16'hFFE0
`define BROWN       16'hBC40
`define BRRED       16'hFC07
`define GRAY        16'h8430
`define DARKBLUE    16'h01CF
`define LIGHTBLUE   16'h7D7C
`define GRAYBLUE    16'h5458
`define LIGHTGREEN  16'h841F
`define LIGHTGRAY   16'hEF5B
`define LGRAY       16'hC618
`define LGRAYBLUE   16'hA651
`define LBBLUE      16'h2B12

// Загальна кількість пікселів для дисплея 800x480
`define TOTAL_PIXELS (800 * 480)

// Координати для області заповнення
`define X_START 0
`define X_END   (480 - 1)
`define Y_START 0
`define Y_END   (800 - 1)

// Стани FSM
`define S_INIT          5'd0
`define S_RESET_LOW     5'd1
`define S_RESET_HIGH    5'd2
`define S_ROM_INIT      5'd3
`define S_READ_ID_PAGE  5'd4
`define S_READ_ID_F001  5'd5
`define S_READ_ID_F002  5'd6
`define S_READ_ID_F003  5'd7
`define S_READ_ID_F004  5'd8
`define S_READ_ID_C500  5'd9
`define S_READ_ID_BYTE1 5'd10
`define S_READ_ID_C501  5'd11
`define S_READ_ID_BYTE2 5'd12
`define S_SOFT_RESET    5'd13
`define S_DELAY         5'd14
`define S_SET_DIR       5'd15
`define S_SET_XSTART_H  5'd16
`define S_SET_XSTART_L  5'd17
`define S_SET_XEND_H    5'd18
`define S_SET_XEND_L    5'd19
`define S_SET_YSTART_H  5'd20
`define S_SET_YSTART_L  5'd21
`define S_SET_YEND_H    5'd22
`define S_SET_YEND_L    5'd23
`define S_DISPLAY_ON    5'd24
`define S_BACKLIGHT     5'd25
`define S_SET_ADDR      5'd26
`define S_PREP_FILL     5'd27
`define S_FILL_PIXELS   5'd28
`define S_LOOP          5'd29
`define S_PAUSE         5'd30

// Типи writer для мультиплексора
`define WRITER_NONE     3'd0
`define WRITER_CMD      3'd1
`define WRITER_CMD_DATA 3'd2
`define WRITER_CMD_NDATA 3'd3
`define WRITER_READ     3'd4

`endif