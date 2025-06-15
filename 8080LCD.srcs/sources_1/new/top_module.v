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
    output [7:0]  la_out,
    output        led_1
    
//    output spi_sclk,            // SPI такт
//    output spi_cs_n,            // SPI Chip Select
//    inout [3:0] spi_dq         // Бідирекційні піни DQ0-DQ3
//    //output wire [15:0] pixel_data // Вихідні дані пікселя
);

wire key_ready;
wire [3:0] key_data_out;
wire [3:0] press_count;
reg  key_read;
reg  [15:0] fill_color;
reg  update_screen;
reg  [15:0] x_start, x_end, y_start, y_end;
wire [7:0] debug_port_1;
reg  init_screen; // Новий регістр для ініціалізації екрана
reg [2:0] state;
reg [31:0] delay_counter;

//assign la_out[7:0] = debug_port_1;

//reg start;
//reg [23:0] addr = 24'h400000; // Початкова адреса зображення
//reg [15:0] num_bytes = 800*480*16;
//wire [7:0] data_out;
//wire valid, done;
//wire [3:0] dq_out;
//wire dq_oe;

//// Quad SPI контролер
//quad_spi_master #(
//	.CLK_FREQ(50_000_000),
//	.SPI_FREQ(10_000_000)
//    ) spi_inst (
//	.clk(clk),
//	.rst(~reset_n),
//	.start(start),
//	.addr(addr),
//	.num_bytes(num_bytes),
//	.data_out(data_out),
//	.valid(valid),
//	.done(done),
//	.sclk(spi_sclk),
//	.cs_n(spi_cs_n),
//    .dq_out(spi_dq_out),
//	.dq_oe(dq_oe),
//	.dq(dq)
//);


lcd lcd_inst (
    .clk(clk),
    .reset_n(reset_n),
    .fill_color(fill_color),
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
    .led_2_reg(led_2)
);

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

// // Логіка збору пікселів
//    reg [7:0] data_buf;
//    reg [15:0] pixel_reg;
//    reg pixel_valid;
    
//assign la_out[7:0] = data_buf[7:0];

//    always @(posedge clk or negedge reset_n) begin
//        if (!reset_n) begin
//            start <= 0;
//            pixel_valid <= 0;
//            data_buf <= 0;
//            pixel_reg <= 0;
//        end else begin
//            if (!start && !done) begin
//                start <= 1; // Почати зчитування
//            end else begin
//                start <= 0;
//            end

//            if (valid) begin
//                if (!pixel_valid) begin
//                    data_buf <= data_out;
//                    pixel_valid <= 1;
//                end else begin
//                    pixel_reg <= {data_buf, data_out};
//                    pixel_valid <= 0;
//                end
//            end
//        end
//    end

//    //assign pixel_data = pixel_reg;
    
reg [4:0] count;
always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        fill_color <= GREEN;
        key_read <= 0;
        update_screen <= 0;
        init_screen <= 1; // Активуємо ініціалізацію екрана після скидання
        x_start <= 0;
        x_end <= 479; // 480-1
        y_start <= 0;
        y_end <= 799; // 800-1
		end else begin
        if (init_screen) begin
            update_screen <= 1; // Запускаємо оновлення екрана
            init_screen <= 0;   // Скидаємо після одного такту
			end else begin
			case (state)
				0: begin                
					case (count)
						5'd1: fill_color <= GRAY;
						5'd2: fill_color <= WHITE;
						5'd3:fill_color <= BLACK; 
						5'd4:fill_color <= BLUE; 
						5'd5:fill_color <= BRED;
						5'd6:fill_color <= GRED;
						5'd7:fill_color <= GBLUE;
						5'd8:fill_color <= RED;
						5'd9:fill_color <= MAGENTA;
						5'd10:fill_color <= GREEN;
						5'd11:fill_color <= CYAN;
						5'd12:fill_color <= YELLOW;
						5'd13:fill_color <= BROWN; 
						5'd14:fill_color <= BRRED;
						5'd15:fill_color <= GRAY ; 
						
						5'd16:fill_color <= DARKBLUE;	
						5'd17:fill_color <= LIGHTBLUE; 
						5'd18:fill_color <= GRAYBLUE; 
						
						5'd19:fill_color <= LIGHTGREEN; 
						5'd20:fill_color <= LIGHTGRAY; 
						5'd21:fill_color <= LGRAY; 
						
						5'd22:fill_color <= LGRAYBLUE; 
						5'd23:fill_color <= LBBLUE;
						5'd24:count <=0;
					endcase
					update_screen <= 1;
					state <= 1;
				end
				1: begin
					count <= count +1;
					delay_counter <= 1000 * LCD_FREQ_MHZ; 
					state <= 2;
				end
				2 : begin
					if (delay_counter > 0) begin
						delay_counter <= delay_counter - 1;
						end else begin
						state <= 0;
					end
				end
			endcase
		end
	end
end

endmodule