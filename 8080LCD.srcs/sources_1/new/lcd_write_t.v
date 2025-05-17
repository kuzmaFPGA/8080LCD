`include "constants.vh"
module lcd_write_cmd (
	input wire clk,          // Системний тактовий сигнал (8 МГц)
	input wire reset_n,      // Активний низький скид
	input wire start,        // Сигнал запуску запису
	input wire [15:0] cmd,   // 16-бітна команда
	output reg LCD_CS,       // Chip Select (активний низький)
	output reg LCD_RS,       // D/CX (0 - команда)
	output reg LCD_WR,       // WRX (write control)
	output reg LCD_RDX,      // RDX (read control)
	output reg [15:0] LCD_DATA, // Шина даних
	output reg done          // Сигнал завершення запису
);

// Регістр стану FSM
reg [2:0] wr_substate;

localparam LCD_RS_CLR = 0, LCD_RS_SET = 1, LCD_CS_CLR = 2, LCD_CS_SET = 3, LCD_WR_CLR = 4, LCD_WR_SET =5, DATAOUT =6;

always @(posedge clk or negedge reset_n) begin
	if (!reset_n) begin
		wr_substate <= 0;
		LCD_CS <= 1;
		LCD_RS <= 0;
		LCD_WR <= 1;
		LCD_RDX <= 1;
		LCD_DATA <= 16'bz;
		done <= 0;
		end else begin
		case (wr_substate)
			LCD_RS_CLR: begin
				if (start) begin
					LCD_RS <= 0; // Команда
					done <= 0;
					wr_substate <= LCD_CS_CLR;
				end
			end
			LCD_CS_CLR: begin
				LCD_CS <= 0;
				wr_substate <= DATAOUT;
			end
			DATAOUT: begin
				LCD_DATA <= cmd; // Встановлення команди
				wr_substate <= LCD_WR_CLR;
			end
			LCD_WR_CLR: begin
				LCD_WR <= 0;
				wr_substate <= LCD_WR_SET;
			end
			LCD_WR_SET: begin
			    LCD_WR <= 1;
			    wr_substate <= LCD_CS_SET;
			end
			LCD_CS_SET: begin
				LCD_CS <= 0;
				done <= 1;
				wr_substate <= LCD_RS_CLR;
			end
			default: wr_substate <= LCD_RS_CLR;
		endcase
	end
end
endmodule

module lcd_write_cmd_data (
	input wire clk,          // Системний тактовий сигнал (8 МГц)
	input wire reset_n,      // Активний низький скид
	input wire start,        // Сигнал запуску запису
	input wire [15:0] cmd,   // 16-бітна команда
	input wire [15:0] data,  // 16-бітні дані
	output reg LCD_CS,       // Chip Select (активний низький)
	output reg LCD_RS,       // D/CX (0 - команда, 1 - дані)
	output reg LCD_WR,       // WRX (write control)
	output reg LCD_RDX,      // RDX (read control)
	output reg [15:0] LCD_DATA, // Шина даних
	output reg done          // Сигнал завершення запису
);

// Регістр стану FSM
reg [3:0] state;
reg [2:0] wr_substate;

// Стани FSM
localparam IDLE = 0, CMD_WRITE = 1, DATA_WRITE = 2, DONE = 3;
localparam LCD_RS_CLR = 0, LCD_RS_SET = 1, LCD_CS_CLR = 2, LCD_CS_SET = 3, LCD_WR_CLR = 4, LCD_WR_SET =5, DATAOUT =6;

always @(posedge clk or negedge reset_n) begin
	if (!reset_n) begin
		state <= IDLE;
		wr_substate <= 0;
		LCD_CS <= 1;
		LCD_RS <= 0;
		LCD_WR <= 1;
		LCD_RDX <= 1;
		LCD_DATA <= 16'bz;
		done <= 0;
		end else begin
		case (state)
			IDLE: begin
				if (start) begin
					state <= CMD_WRITE;
					wr_substate <= 0;
					done <= 0;
				end
			end
			CMD_WRITE: begin
				case (wr_substate)
					LCD_RS_CLR: begin
						if (start) begin
							LCD_RS <= 0; // Команда
							wr_substate <= LCD_CS_CLR;
						end
					end
					LCD_CS_CLR: begin
						LCD_CS <= 0;
						wr_substate <= DATAOUT;
					end
					DATAOUT: begin
						LCD_DATA <= cmd; // Встановлення команди
						wr_substate <= LCD_WR_CLR;
					end
					LCD_WR_CLR: begin
						LCD_WR <= 0;
						wr_substate <= LCD_WR_SET;
					end
					LCD_WR_SET: begin
						LCD_WR <= 1;
						wr_substate <= LCD_CS_SET;
					end
					LCD_CS_SET: begin
						LCD_CS <= 0;
						wr_substate <= LCD_RS_SET;
						state <= DATA_WRITE;
					end
					default: wr_substate <= LCD_RS_CLR;
				endcase
			end
			DATA_WRITE: begin
				case (wr_substate)
					LCD_RS_SET: begin
						if (start) begin
							LCD_RS <= 1; // data
							wr_substate <= LCD_CS_CLR;
						end
					end
					LCD_CS_CLR: begin
						LCD_CS <= 0;
						wr_substate <= DATAOUT;
					end
					DATAOUT: begin
						LCD_DATA <= data; // Встановлення data
						wr_substate <= LCD_WR_CLR;
					end
					LCD_WR_CLR: begin
						LCD_WR <= 0;
						wr_substate <= LCD_WR_SET;
					end
					LCD_WR_SET: begin
						LCD_WR <= 1;
						wr_substate <= LCD_CS_SET;
					end
					LCD_CS_SET: begin
						LCD_CS <= 0;
						wr_substate <= LCD_RS_CLR;
						state <= DONE;
					end
					default: wr_substate <= LCD_RS_CLR;
				endcase
				
			end
			DONE: begin
				done <= 1;
				state <= IDLE;
			end
			default: state <= IDLE;
		endcase
	end
end
endmodule

module lcd_write_cmd_ndata (
	input wire clk,          // Системний тактовий сигнал (8 МГц)
	input wire reset_n,      // Активний низький скид
	input wire start,        // Сигнал запуску запису
	input wire [15:0] cmd,   // 16-бітна команда
	input wire [15:0] data,  // 16-бітні дані (надходять послідовно)
	input wire [31:0] n,     // Кількість даних для запису
	output reg LCD_CS,       // Chip Select (активний низький)
	output reg LCD_RS,       // D/CX (0 - команда, 1 - дані)
	output reg LCD_WR,       // WRX (write control)
	output reg LCD_RDX,      // RDX (read control)
	output reg [15:0] LCD_DATA, // Шина даних
	output reg done          // Сигнал завершення запису
);

// Регістр стану FSM
reg [3:0] state;
reg [2:0] wr_substate;
reg [31:0] data_count;   // Лічильник записаних даних

// Стани FSM
localparam IDLE = 0, CMD_WRITE = 1, DATA_WRITE = 2, DONE = 3;
localparam LCD_RS_CLR_C = 0, LCD_RS_SET_C = 1, LCD_CS_CLR_C = 2, LCD_CS_SET_C = 3, LCD_WR_CLR_C = 4, LCD_WR_SET_C =5, DATAOUT_C =6,
             LCD_RS_CLR_D = 7, LCD_RS_SET_D = 8, LCD_CS_CLR_D = 9, LCD_CS_SET_D = 10, LCD_WR_CLR_D = 11, LCD_WR_SET_D =12, DATAOUT_D =13;

always @(posedge clk or negedge reset_n) begin
	if (!reset_n) begin
		state <= IDLE;
		wr_substate <= 0;
		data_count <= 0;
		LCD_CS <= 1;
		LCD_RS <= 0;
		LCD_WR <= 1;
		LCD_RDX <= 1;
		LCD_DATA <= 16'bz;
		done <= 0;
		end else begin
		case (state)
			IDLE: begin
				if (start) begin
					state <= S_SET_DIR;
					wr_substate <= LCD_RS_CLR_C;
					data_count <= 0;
					done <= 0;
				end
			end
			S_SET_DIR: begin // Set direction (0x3600, 0x00)
//                    cmd_data <= 16'h3600;
//                    write_data <= 16'h00;
				case (wr_substate)
					LCD_RS_CLR_C: begin
						if (start) begin
							LCD_RS <= 0; // Команда
							wr_substate <= LCD_CS_CLR_C;
						end
					end
					LCD_CS_CLR_C: begin
						LCD_CS <= 0;
						wr_substate <= DATAOUT_C;
					end
					DATAOUT_C: begin
						LCD_DATA <= 16'h3600; // Встановлення команди
						wr_substate <= LCD_WR_CLR_C;
					end
					LCD_WR_CLR_C: begin
						LCD_WR <= 0;
						wr_substate <= LCD_WR_SET_C;
					end
					LCD_WR_SET_C: begin
						LCD_WR <= 1;
						wr_substate <= LCD_CS_SET_C;
					end
					LCD_CS_SET_C: begin
						LCD_CS <= 0;
						wr_substate <= LCD_RS_SET_D;
						state <= DATA_WRITE;
					end
				
					LCD_RS_SET_D: begin
						if (start) begin
							LCD_RS <= 1; // data
							wr_substate <= LCD_CS_CLR_D;
						end
					end
					LCD_CS_CLR_D: begin
						LCD_CS <= 0;
						wr_substate <= DATAOUT_D;
					end
					DATAOUT_D: begin
						LCD_DATA <= 16'h00; // Встановлення data
						wr_substate <= LCD_WR_CLR_D;
					end
					LCD_WR_CLR_D: begin
						LCD_WR <= 0;
						wr_substate <= LCD_WR_SET_D;
					end
					LCD_WR_SET_D: begin
						LCD_WR <= 1;
						wr_substate <= LCD_CS_SET_D;
					end
					LCD_CS_SET_D: begin
						LCD_CS <= 0;
						wr_substate <= LCD_RS_CLR_C;
						state <= S_SET_XSTART_H;
					end
				endcase
            end
            S_SET_XSTART_H: begin // Set xStart high byte
//                    cmd_data <= 16'h2A00;
//                    write_data <= (x_start >> 8);
                case (wr_substate)
					LCD_RS_CLR_C: begin
						if (start) begin
							LCD_RS <= 0; // Команда
							wr_substate <= LCD_CS_CLR_C;
						end
					end
					LCD_CS_CLR_C: begin
						LCD_CS <= 0;
						wr_substate <= DATAOUT_C;
					end
					DATAOUT_C: begin
						LCD_DATA <= 16'h2A00; // Встановлення команди
						wr_substate <= LCD_WR_CLR_C;
					end
					LCD_WR_CLR_C: begin
						LCD_WR <= 0;
						wr_substate <= LCD_WR_SET_C;
					end
					LCD_WR_SET_C: begin
						LCD_WR <= 1;
						wr_substate <= LCD_CS_SET_C;
					end
					LCD_CS_SET_C: begin
						LCD_CS <= 0;
						wr_substate <= LCD_RS_SET_D;
						state <= DATA_WRITE;
					end
				
					LCD_RS_SET_D: begin
						if (start) begin
							LCD_RS <= 1; // data
							wr_substate <= LCD_CS_CLR_D;
						end
					end
					LCD_CS_CLR_D: begin
						LCD_CS <= 0;
						wr_substate <= DATAOUT_D;
					end
					DATAOUT_D: begin
						LCD_DATA <= (x_start >> 8); // Встановлення data
						wr_substate <= LCD_WR_CLR_D;
					end
					LCD_WR_CLR_D: begin
						LCD_WR <= 0;
						wr_substate <= LCD_WR_SET_D;
					end
					LCD_WR_SET_D: begin
						LCD_WR <= 1;
						wr_substate <= LCD_CS_SET_D;
					end
					LCD_CS_SET_D: begin
						LCD_CS <= 0;
						wr_substate <= LCD_RS_CLR_C;
						state <= S_SET_XSTART_L;
					end
				endcase
            end
            S_SET_XSTART_L: begin // Set xStart low byte
//                    cmd_data <= 16'h2A01;
//                    write_data <= (x_start & 16'hFF);
//                    state <= S_SET_XEND_H;
                case (wr_substate)
					LCD_RS_CLR_C: begin
						if (start) begin
							LCD_RS <= 0; // Команда
							wr_substate <= LCD_CS_CLR_C;
						end
					end
					LCD_CS_CLR_C: begin
						LCD_CS <= 0;
						wr_substate <= DATAOUT_C;
					end
					DATAOUT_C: begin
						LCD_DATA <= 16'h2A01; // Встановлення команди
						wr_substate <= LCD_WR_CLR_C;
					end
					LCD_WR_CLR_C: begin
						LCD_WR <= 0;
						wr_substate <= LCD_WR_SET_C;
					end
					LCD_WR_SET_C: begin
						LCD_WR <= 1;
						wr_substate <= LCD_CS_SET_C;
					end
					LCD_CS_SET_C: begin
						LCD_CS <= 0;
						wr_substate <= LCD_RS_SET_D;
						state <= DATA_WRITE;
					end
				
					LCD_RS_SET_D: begin
						if (start) begin
							LCD_RS <= 1; // data
							wr_substate <= LCD_CS_CLR_D;
						end
					end
					LCD_CS_CLR_D: begin
						LCD_CS <= 0;
						wr_substate <= DATAOUT_D;
					end
					DATAOUT_D: begin
						LCD_DATA <= (x_start & 16'hFF); // Встановлення data
						wr_substate <= LCD_WR_CLR_D;
					end
					LCD_WR_CLR_D: begin
						LCD_WR <= 0;
						wr_substate <= LCD_WR_SET_D;
					end
					LCD_WR_SET_D: begin
						LCD_WR <= 1;
						wr_substate <= LCD_CS_SET_D;
					end
					LCD_CS_SET_D: begin
						LCD_CS <= 0;
						wr_substate <= LCD_RS_CLR_C;
						state <= S_SET_XEND_H;
					end
				endcase
            end
            S_SET_XEND_H: begin // Set xEnd high byte
//                    cmd_data <= 16'h2A02;
//                    write_data <= (x_end >> 8);
//                    state <= S_SET_XEND_L;
                case (wr_substate)
					LCD_RS_CLR_C: begin
						if (start) begin
							LCD_RS <= 0; // Команда
							wr_substate <= LCD_CS_CLR_C;
						end
					end
					LCD_CS_CLR_C: begin
						LCD_CS <= 0;
						wr_substate <= DATAOUT_C;
					end
					DATAOUT_C: begin
						LCD_DATA <= 16'h2A02; // Встановлення команди
						wr_substate <= LCD_WR_CLR_C;
					end
					LCD_WR_CLR_C: begin
						LCD_WR <= 0;
						wr_substate <= LCD_WR_SET_C;
					end
					LCD_WR_SET_C: begin
						LCD_WR <= 1;
						wr_substate <= LCD_CS_SET_C;
					end
					LCD_CS_SET_C: begin
						LCD_CS <= 0;
						wr_substate <= LCD_RS_SET_D;
						state <= DATA_WRITE;
					end
				
					LCD_RS_SET_D: begin
						if (start) begin
							LCD_RS <= 1; // data
							wr_substate <= LCD_CS_CLR_D;
						end
					end
					LCD_CS_CLR_D: begin
						LCD_CS <= 0;
						wr_substate <= DATAOUT_D;
					end
					DATAOUT_D: begin
						LCD_DATA <= (x_end >> 8); // Встановлення data
						wr_substate <= LCD_WR_CLR_D;
					end
					LCD_WR_CLR_D: begin
						LCD_WR <= 0;
						wr_substate <= LCD_WR_SET_D;
					end
					LCD_WR_SET_D: begin
						LCD_WR <= 1;
						wr_substate <= LCD_CS_SET_D;
					end
					LCD_CS_SET_D: begin
						LCD_CS <= 0;
						wr_substate <= LCD_RS_CLR_C;
						state <= S_SET_XEND_L;
					end
				endcase
            end
            S_SET_XEND_L: begin // Set xEnd low byte
//                    cmd_data <= 16'h2A03;
//                    write_data <= (x_end & 16'hFF);
//                    state <= S_SET_YSTART_H;
                case (wr_substate)
					LCD_RS_CLR_C: begin
						if (start) begin
							LCD_RS <= 0; // Команда
							wr_substate <= LCD_CS_CLR_C;
						end
					end
					LCD_CS_CLR_C: begin
						LCD_CS <= 0;
						wr_substate <= DATAOUT_C;
					end
					DATAOUT_C: begin
						LCD_DATA <= 16'h2A03; // Встановлення команди
						wr_substate <= LCD_WR_CLR_C;
					end
					LCD_WR_CLR_C: begin
						LCD_WR <= 0;
						wr_substate <= LCD_WR_SET_C;
					end
					LCD_WR_SET_C: begin
						LCD_WR <= 1;
						wr_substate <= LCD_CS_SET_C;
					end
					LCD_CS_SET_C: begin
						LCD_CS <= 0;
						wr_substate <= LCD_RS_SET_D;
						state <= DATA_WRITE;
					end
				
					LCD_RS_SET_D: begin
						if (start) begin
							LCD_RS <= 1; // data
							wr_substate <= LCD_CS_CLR_D;
						end
					end
					LCD_CS_CLR_D: begin
						LCD_CS <= 0;
						wr_substate <= DATAOUT_D;
					end
					DATAOUT_D: begin
						LCD_DATA <= (x_end & 16'hFF); // Встановлення data
						wr_substate <= LCD_WR_CLR_D;
					end
					LCD_WR_CLR_D: begin
						LCD_WR <= 0;
						wr_substate <= LCD_WR_SET_D;
					end
					LCD_WR_SET_D: begin
						LCD_WR <= 1;
						wr_substate <= LCD_CS_SET_D;
					end
					LCD_CS_SET_D: begin
						LCD_CS <= 0;
						wr_substate <= LCD_RS_CLR_C;
						state <= S_SET_YSTART_H;
					end
				endcase
            end
            S_SET_YSTART_H: begin // Set yStart high byte
//                    cmd_data <= 16'h2B00;
//                    write_data <= (y_start >> 8);
//                    state <= S_SET_YSTART_L;
                case (wr_substate)
					LCD_RS_CLR_C: begin
						if (start) begin
							LCD_RS <= 0; // Команда
							wr_substate <= LCD_CS_CLR_C;
						end
					end
					LCD_CS_CLR_C: begin
						LCD_CS <= 0;
						wr_substate <= DATAOUT_C;
					end
					DATAOUT_C: begin
						LCD_DATA <= 16'h2B00; // Встановлення команди
						wr_substate <= LCD_WR_CLR_C;
					end
					LCD_WR_CLR_C: begin
						LCD_WR <= 0;
						wr_substate <= LCD_WR_SET_C;
					end
					LCD_WR_SET_C: begin
						LCD_WR <= 1;
						wr_substate <= LCD_CS_SET_C;
					end
					LCD_CS_SET_C: begin
						LCD_CS <= 0;
						wr_substate <= LCD_RS_SET_D;
						state <= DATA_WRITE;
					end
				
					LCD_RS_SET_D: begin
						if (start) begin
							LCD_RS <= 1; // data
							wr_substate <= LCD_CS_CLR_D;
						end
					end
					LCD_CS_CLR_D: begin
						LCD_CS <= 0;
						wr_substate <= DATAOUT_D;
					end
					DATAOUT_D: begin
						LCD_DATA <= (y_start >> 8); // Встановлення data
						wr_substate <= LCD_WR_CLR_D;
					end
					LCD_WR_CLR_D: begin
						LCD_WR <= 0;
						wr_substate <= LCD_WR_SET_D;
					end
					LCD_WR_SET_D: begin
						LCD_WR <= 1;
						wr_substate <= LCD_CS_SET_D;
					end
					LCD_CS_SET_D: begin
						LCD_CS <= 0;
						wr_substate <= LCD_RS_CLR_C;
						state <= S_SET_YSTART_L;
					end
				endcase
            end
            S_SET_YSTART_L: begin // Set yStart low byte
//                    cmd_data <= 16'h2B01;
//                    write_data <= (y_start & 16'hFF);
//                    state <= S_SET_YEND_H;
            end
            S_SET_YEND_H: begin // Set yEnd high byte
//                    cmd_data <= 16'h2B02;
//                    write_data <= (y_end >> 8);
//                    state <= S_SET_YEND_L;
            end
            S_SET_YEND_L: begin // Set yEnd low byte
                    cmd_data <= 16'h2B03;
                    write_data <= (y_end & 16'hFF);
                    state <= S_SET_ADDR;
            end
            S_SET_ADDR: begin // Set address (0x2C00)
                    cmd_data <= 16'h2C00;
                    state <= CMD_WRITE_FILL;
            end
//            S_PREP_FILL: begin // Prepare for pixel fill
//                pixel_cnt <= 0;
//                total_pixels <= (x_end - x_start + 1) * (y_end - y_start + 1);
//                state <= S_FILL_PIXELS;
//            end
			CMD_WRITE_FILL: begin
				case (wr_substate)
					0: begin
						LCD_CS <= 1;
						LCD_RS <= 0; // Команда
						LCD_WR <= 1;
						LCD_RDX <= 1;
						LCD_DATA <= 16'bz;
						wr_substate <= 1;
					end
					1: begin
						LCD_CS <= 0;
						LCD_RS <= 0;
						LCD_WR <= 1;
						LCD_RDX <= 1;
						LCD_DATA <= 16'bz;
						wr_substate <= 2;
					end
					2: begin
						LCD_CS <= 0;
						LCD_RS <= 0;
						LCD_WR <= 0;
						LCD_RDX <= 1;
						LCD_DATA <= 16'bz;
						wr_substate <= 3;
					end
					3: begin
						LCD_CS <= 0;
						LCD_RS <= 0;
						LCD_WR <= 0;
						LCD_RDX <= 1;
						LCD_DATA <= cmd;
						wr_substate <= 4;
					end
					4: begin
						LCD_CS <= 0;
						LCD_RS <= 0;
						LCD_WR <= 1;
						LCD_RDX <= 1;
						LCD_DATA <= cmd;
						wr_substate <= 5;
					end
					5: begin
						LCD_CS <= 1;
						LCD_RS <= 0;
						LCD_WR <= 1;
						LCD_RDX <= 1;
						LCD_DATA <= 16'bz;
						state <= (n > 0) ? DATA_WRITE : DONE;
						wr_substate <= 0;
					end
				endcase
			end
			DATA_FILL: begin
				case (wr_substate)
					0: begin
						LCD_CS <= 1;
						LCD_RS <= 1; // Дані
						LCD_WR <= 1;
						LCD_RDX <= 1;
						LCD_DATA <= 16'bz;
						wr_substate <= 1;
					end
					1: begin
						LCD_CS <= 0;
						LCD_RS <= 1;
						LCD_WR <= 1;
						LCD_RDX <= 1;
						LCD_DATA <= 16'bz;
						wr_substate <= 2;
					end
					2: begin
						LCD_CS <= 0;
						LCD_RS <= 1;
						LCD_WR <= 0;
						LCD_RDX <= 1;
						LCD_DATA <= 16'bz;
						wr_substate <= 3;
					end
					3: begin
						LCD_CS <= 0;
						LCD_RS <= 1;
						LCD_WR <= 0;
						LCD_RDX <= 1;
						LCD_DATA <= data;
						wr_substate <= 4;
					end
					4: begin
						LCD_CS <= 0;
						LCD_RS <= 1;
						LCD_WR <= 1;
						LCD_RDX <= 1;
						LCD_DATA <= data;
						wr_substate <= 5;
					end
					5: begin
						LCD_CS <= 1;
						LCD_RS <= 1;
						LCD_WR <= 1;
						LCD_RDX <= 1;
						LCD_DATA <= 16'bz;
						data_count <= data_count + 1;
						if (data_count + 1 >= n) begin
							state <= DONE;
						end
						wr_substate <= 0;
					end
				endcase
			end
			DONE: begin
				done <= 1;
				state <= IDLE;
			end
			default: state <= IDLE;
		endcase
	end
end
endmodule

module lcd_write_pixel (
    input clk, reset_n, start,
    input [15:0] x, y, color,
    output reg done,
    output reg [15:0] LCD_DATA,
    output reg LCD_CS, LCD_RS, LCD_WR, LCD_RDX
);
reg [3:0] state;
always @(posedge clk or negedge reset_n) begin
	if (!reset_n) begin
		state <= 0;
		LCD_CS <= 1;
		LCD_RS <= 0;
		LCD_WR <= 1;
		LCD_RDX <= 1;
		LCD_DATA <= 0;
		done <= 0;
        end else begin
		case (state)
			0: begin // 0x2A00
				if (start) begin
					LCD_CS <= 0;
					LCD_RS <= 0;
					LCD_DATA <= 16'h2A00;
					LCD_WR <= 0;
					state <= 1;
				end
			end
			1: begin
				LCD_WR <= 1;
				LCD_RS <= 1;
				LCD_DATA <= x >> 8;
				LCD_WR <= 0;
				state <= 2;
			end
			2: begin
				LCD_WR <= 1;
				LCD_RS <= 0;
				LCD_DATA <= 16'h2A01;
				LCD_WR <= 0;
				state <= 3;
			end
			3: begin
				LCD_WR <= 1;
				LCD_RS <= 1;
				LCD_DATA <= x & 16'hFF;
				LCD_WR <= 0;
				state <= 4;
			end
			4: begin
				LCD_WR <= 1;
				LCD_RS <= 0;
				LCD_DATA <= 16'h2A02;
				LCD_WR <= 0;
				state <= 5;
			end
			5: begin
				LCD_WR <= 1;
				LCD_RS <= 1;
				LCD_DATA <= x >> 8;
				LCD_WR <= 0;
				state <= 6;
			end
			6: begin
				LCD_WR <= 1;
				LCD_RS <= 0;
				LCD_DATA <= 16'h2A03;
				LCD_WR <= 0;
				state <= 7;
			end
			7: begin
				LCD_WR <= 1;
				LCD_RS <= 1;
				LCD_DATA <= x & 16'hFF;
				LCD_WR <= 0;
				state <= 8;
			end
			8: begin
				LCD_WR <= 1;
				LCD_RS <= 0;
				LCD_DATA <= 16'h2B00;
				LCD_WR <= 0;
				state <= 9;
			end
			9: begin
				LCD_WR <= 1;
				LCD_RS <= 1;
				LCD_DATA <= y >> 8;
				LCD_WR <= 0;
				state <= 10;
			end
			10: begin
				LCD_WR <= 1;
				LCD_RS <= 0;
				LCD_DATA <= 16'h2B01;
				LCD_WR <= 0;
				state <= 11;
			end
			11: begin
				LCD_WR <= 1;
				LCD_RS <= 1;
				LCD_DATA <= y & 16'hFF;
				LCD_WR <= 0;
				state <= 12;
			end
			12: begin
				LCD_WR <= 1;
				LCD_RS <= 0;
				LCD_DATA <= 16'h2B02;
				LCD_WR <= 0;
				state <= 13;
			end
			13: begin
				LCD_WR <= 1;
				LCD_RS <= 1;
				LCD_DATA <= y >> 8;
				LCD_WR <= 0;
				state <= 14;
			end
			14: begin
				LCD_WR <= 1;
				LCD_RS <= 0;
				LCD_DATA <= 16'h2B03;
				LCD_WR <= 0;
				state <= 15;
			end
			15: begin
				LCD_WR <= 1;
				LCD_RS <= 1;
				LCD_DATA <= y & 16'hFF;
				LCD_WR <= 0;
				state <= 16;
			end
			16: begin
				LCD_WR <= 1;
				LCD_RS <= 0;
				LCD_DATA <= 16'h2C00;
				LCD_WR <= 0;
				state <= 17;
			end
			17: begin
				LCD_WR <= 1;
				LCD_RS <= 1;
				LCD_DATA <= color;
				LCD_WR <= 0;
				state <= 18;
			end
			18: begin
				LCD_WR <= 1;
				LCD_CS <= 1;
				done <= 1;
				state <= 19;
			end
			19: begin
				if (!start) begin
					done <= 0;
					state <= 0;
				end
			end
		endcase
	end
end
endmodule

module lcd_read_data (
    input clk, reset_n, start,
    output reg [15:0] data,
    output reg done,
    output reg LCD_CS, LCD_RS, LCD_WR, LCD_RDX,
    input [15:0] LCD_DATA
);
reg [2:0] state;
always @(posedge clk or negedge reset_n) begin
	if (!reset_n) begin
		state <= 0;
		LCD_CS <= 1;
		LCD_RS <= 1;
		LCD_WR <= 1;
		LCD_RDX <= 1;
		done <= 0;
		data <= 0;
        end else begin
		case (state)
			0: begin
				if (start) begin
					LCD_CS <= 0;
					LCD_RS <= 1;
					state <= 1;
				end
			end
			1: begin
				LCD_RDX <= 0;
				state <= 2;
			end
			2: begin
				data <= LCD_DATA;
				state <= 3;
			end
			3: begin
				LCD_RDX <= 1;
				state <= 4;
			end
			4: begin
				LCD_CS <= 1;
				done <= 1;
				state <= 5;
			end
			5: begin
				if (!start) begin
					done <= 0;
					state <= 0;
				end
			end
		endcase
	end
end
endmodule