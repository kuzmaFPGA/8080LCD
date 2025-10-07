`include "constants.vh"

module top_level (
    input         clk,
    input         reset_n,
    input  [3:0]  row_data_in,
    output [3:0]  col_data_out,
    output [15:0] LCD_DATA,
    output        LCD_WR,
    output        LCD_RS,
    output        LCD_CS,
    output        LCD_RESET,
    output        LCD_BL,
    output        LCD_RDX,
    //output [7:0]  la_out,
    output        led_1,
    // Сигнали для XPT2046
    output        ts_clk,        // SPI такт (DCLK)
    output        ts_cs,         // SPI Chip Select (CS_N)
    input         ts_miso,       // SPI MISO (DOUT)
    output        ts_mosi,       // SPI MOSI (DIN)
    input         ts_pen,         // Сигнал переривання від XPT2046
    
`ifdef XILINX_SIMULATOR    
    output [31:0]data_count,
    output [2:0]state,
    output [17:0]bram_addra,
    output cmd_ndata_done,
    output start_read_data,
`endif
	// Інтерфейс SDRAM
    output SDRAM_CKE, // Сигнал активації годинника SDRAM (Clock Enable)
    output SDRAM_WEn, // Сигнал дозволу запису (Write Enable)
    output SDRAM_CASn, // Сигнал активації стовпця (Column Address Strobe)
    output SDRAM_RASn, // Сигнал активації рядка (Row Address Strobe)
    output reg [12:0] SDRAM_A, // Адресна шина SDRAM (13 біт для W9825G6KH)
    output reg [1:0] SDRAM_BA, // Вибір банку пам'яті (Bank Address, 2 біти для 4 банків)
    output reg [1:0] SDRAM_DQM, // Маска даних (Data Mask), за замовчуванням вимкнено
    inout [15:0] SDRAM_DQ // Шина даних SDRAM (16 біт, двонаправлена)

);

wire key_ready;
wire [3:0] key_data_out;
wire [4:0] press_count;
reg  key_read;
reg  [15:0] fill_color;
reg  update_screen;
reg  init_done;
reg [31:0] data_count;
reg  start_read_data;
reg cmd_done;
reg cmd_data_done;
reg cmd_ndata_done;
reg  [15:0] x_start, x_end, y_start, y_end;
wire [7:0] debug_port_1;
//reg  init_screen;
reg  [2:0] state;
reg  [31:0] delay_counter;
reg  [4:0]  lcd_state;
// Сигнали для XPT2046
wire [11:0] x_value, y_value;
wire get_flag;
reg  touch_en;

// Сигнали для BRAM
wire bram_douta;
reg [17:0] bram_addra;
wire [15:0] pixel_data;

// Інтерфейс для читання (read agent)
wire RdReq; // Сигнал запиту на читання
wire RdGnt; // Сигнал підтвердження читання
reg [23:0] RdAddr; // Адреса для читання (24 біти: 2 банк + 13 рядок + 9 стовпець)
reg [15:0] RdData; // Дані, прочитані з SDRAM
wire RdDataValid; // Сигнал, що вказує на валідність прочитаних даних

// Інтерфейс для запису (write agent)
wire WrReq; // Сигнал запиту на запис
wire WrGnt; // Сигнал підтвердження запису
reg [23:0] WrAddr; // Адреса для запису (24 біти)
reg [15:0] WrData; // Дані для запису в SDRAM

wire clk_main;

clk_wiz_1 main_clk_pll (
    .clk_in1(clk),
    .resetn(reset_n),
    .clk_out1(clk_main)
);

// FSM стани
localparam S_INIT = 0, S_WAIT = 1, S_TRIGGER_WAIT = 2, S_DISPLAY = 3, S_PAUSE = 4, S_NEXT_SYMBOL = 5;
localparam MAX_TEXT_INDEX = 10;

localparam TEXT_COLOR = RED;
localparam TEXT_BACK_COLOR = WHITE;
reg [7:0] current_text_index = 0;
blk_mem_gen_0 bram (
	.clka(clk),    // input wire clka
	.addra(bram_addra),  // input wire [13 : 0] addra
	.douta(bram_douta)  // output wire [15 : 0] douta
);

SDRAM_ctrl SDRAM_ctrl(
    .clk(clk), // Вхідний тактовий сигнал для синхронізації роботи контролера
	
    // Інтерфейс для читання (read agent)
    .RdReq, // Сигнал запиту на читання
    .RdGnt, // Сигнал підтвердження читання
    .RdAddr, // Адреса для читання (24 біти: 2 банк + 13 рядок + 9 стовпець)
    .RdData, // Дані, прочитані з SDRAM
    .RdDataValid, // Сигнал, що вказує на валідність прочитаних даних
	
    // Інтерфейс для запису (write agent)
    .WrReq, // Сигнал запиту на запис
    .WrGnt, // Сигнал підтвердження запису
    .WrAddr, // Адреса для запису (24 біти)
    .WrData, // Дані для запису в SDRAM
	
    // Інтерфейс SDRAM
    .SDRAM_CKE(SDRAM_CKE), // Сигнал активації годинника SDRAM (Clock Enable)
    .SDRAM_WEn(SDRAM_WEn), // Сигнал дозволу запису (Write Enable)
    .SDRAM_CASn(SDRAM_CASn), // Сигнал активації стовпця (Column Address Strobe)
    .SDRAM_RASn(SDRAM_RASn), // Сигнал активації рядка (Row Address Strobe)
    .SDRAM_A(SDRAM_A), // Адресна шина SDRAM (13 біт для W9825G6KH)
    .SDRAM_BA(SDRAM_BA), // Вибір банку пам'яті (Bank Address, 2 біти для 4 банків)
    .SDRAM_DQM(SDRAM_DQM), // Маска даних (Data Mask), за замовчуванням вимкнено
    .SDRAM_DQ(SDRAM_DQ) // Шина даних SDRAM (16 біт, двонаправлена)
);
// LCD інстанція
lcd lcd_inst (
    .clk(clk),
    .reset_n(reset_n),
    .fill_color(pixel_data), // Використовуємо пікселі з BRAM
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
    .debug_port_1(debug_port_1),
    .led_1_reg(led_1),
    .led_2_reg(),
    .start_read_data(start_read_data),
    .cmd_done(cmd_done),
    .cmd_data_done(cmd_data_done),
    .cmd_ndata_done(cmd_ndata_done),
    .lcd_clk(lcd_clk),  // Підключаємо lcd_clk
    .lcd_state(lcd_state),
    .init_done(init_done),
    .lcd_data_count(data_count)
);

// KeyPad інстанція
KeyPadInterpreter keypad_inst (
    .Clock(clk),
    .ResetButton(reset_n),
    .KeyRead(key_read),
    .RowDataIn(row_data_in),
    .KeyReady(key_ready),
    .DataOut(key_data_out),
    .ColDataOut(col_data_out),
    .PressCount(press_count)
);

// XPT2046 інстанція
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

// Логіка для сенсорного екрана
always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        touch_en <= 1'b0;
		end else begin
        touch_en <= 1'b1;
	end
end
reg onesecpulse;
// FSM для керування
always @(posedge lcd_clk or negedge reset_n) begin
    if (!reset_n) begin
        bram_addra <= current_text_index * TEXT_WIDTH * TEXT_HEIGH;
        state <= S_INIT;
        update_screen <= 0;
        x_start <= 0;
        x_end <= TEXT_WIDTH - 1; // 32-1
        y_start <= 0;
        y_end <= TEXT_HEIGH -1; // 31-1
        fill_color <= GREEN;
        key_read <= 0;
        delay_counter <= 0;
		end else begin
        case (state)
            S_INIT: begin
                if (init_done) begin
                    state <= S_WAIT;
                    delay_counter <= DELAY_1S; // 1 с затримки
				end
			end    
            S_WAIT: begin
                if (delay_counter > 0) begin
                    delay_counter <= delay_counter - 1;
					end else begin
                    state <= S_TRIGGER_WAIT;
                    update_screen <= 1;
                    delay_counter <= DELAY_TRIGGER;
				end
			end
            S_TRIGGER_WAIT: begin
                if (delay_counter > 0) begin
                    delay_counter <= delay_counter - 1;
					end 
				else begin
                    state <= S_DISPLAY;
                    update_screen <= 0;
                    bram_addra <= current_text_index * TEXT_WIDTH * TEXT_HEIGH;
				end
			end
            S_DISPLAY: begin
                if (start_read_data) begin
                    bram_addra <= current_text_index * TEXT_WIDTH * TEXT_HEIGH + data_count;
                    if (cmd_ndata_done) begin
                        //bram_addra <= current_text_index * TEXT_WIDTH * TEXT_HEIGH;
                        delay_counter <= DELAY_1S; // 1 с затримки
                        state <= S_PAUSE;
					end
				end
			end
            S_PAUSE: begin
					if (delay_counter > 0) begin
						delay_counter <= delay_counter - 1;
						end else begin
						state <= S_NEXT_SYMBOL;
						onesecpulse <= ~onesecpulse;
					end
			end       
			S_NEXT_SYMBOL:begin
                if (current_text_index <= MAX_TEXT_INDEX) begin
						current_text_index <= current_text_index + 1;
						state <= S_TRIGGER_WAIT;
						update_screen <= 1;
						delay_counter <= DELAY_TRIGGER;
				end
				else begin
				    current_text_index <=0;
				end
			end      
			     
		endcase
	end
end
assign pixel_data = bram_douta? TEXT_COLOR: TEXT_BACK_COLOR;
//assign la_out[7:1] = bram_addra[7:1];
//assign la_out[0:0] = start_read_data;
//assign la_out[5:1] = lcd_state[4:0];
//assign la_out[7:6] = state;
assign led_1 = onesecpulse;

endmodule