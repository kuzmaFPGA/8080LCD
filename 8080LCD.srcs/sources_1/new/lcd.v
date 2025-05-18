`include "constants.vh"

module lcd (
    input            clk,        // System clock
    input            reset_n,    // Active-low reset
    input     [15:0] fill_color, // Color for screen fill (RGB565)
    input     [15:0] x_start,    // Window x start coordinate
    input     [15:0] x_end,      // Window x end coordinate
    input     [15:0] y_start,    // Window y start coordinate
    input     [15:0] y_end,      // Window y end coordinate
    input            update_screen, // Trigger to update screen
    output    [15:0] LCD_DATA,   // LCD data bus
    output           LCD_WR,     // WRX (write control)
    output           LCD_RS,     // D/CX (0 - command, 1 - data)
    output           LCD_CS,     // CSX (active low)
    output           LCD_RESET,  // LCD reset (active low)
    output           LCD_BL,     // Backlight
    output           LCD_RDX,    // RDX (read control)
    output    [7:0]  debug_port_1,
    output           led_1_reg,
    output           led_2_reg
);

// Output registers
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

wire pll_locked;

// PLL for generating lcd_clk (8 MHz)
clk_wiz_0 lcd_clk_pll (
    .clk_in1(clk),
    .resetn(reset_n),
    .clk_out1(lcd_clk),
    .locked(pll_locked)
);

assign led_1_reg = ~pll_locked;
assign led_2_reg = ~update_screen;

// Initialization ROM
reg [15:0] init_rom [0:779]; // 780 rows
initial $readmemh("init.mem", init_rom);
reg [9:0] init_rom_addr;     // Address counter

// Data and type for writing
reg [15:0] cmd_data;         // Command
reg [15:0] write_data;       // Data for cmd_data module

// State machine
state_t state;               // Використовуємо тип state_t
//fill_substate_t fill_substate; // Використовуємо тип fill_substate_t

assign debug_port_1 = state;
//assign debug_port_2 = fill_substate;

// Delay counter
reg [31:0] delay_counter;

// Control signals for modules
reg cmd_start;               // Start lcd_write_cmd
reg cmd_data_start;          // Start lcd_write_cmd_data
reg cmd_ndata_start;         // Start lcd_write_cmd_ndata
wire cmd_done;               // lcd_write_cmd done
wire cmd_data_done;          // lcd_write_cmd_data done
wire cmd_ndata_done;         // lcd_write_cmd_ndata done

// Signals for multiplexer
wire [15:0] cmd_LCD_DATA, cmd_data_LCD_DATA, cmd_ndata_LCD_DATA, cmd_read_LCD_DATA;
wire cmd_LCD_CS, cmd_data_LCD_CS, cmd_ndata_LCD_CS, cmd_read_LCD_CS;
wire cmd_LCD_RS, cmd_data_LCD_RS, cmd_ndata_LCD_RS, cmd_read_LCD_RS;
wire cmd_LCD_WR, cmd_data_LCD_WR, cmd_ndata_LCD_WR, cmd_read_LCD_WR;
wire cmd_LCD_RDX, cmd_data_LCD_RDX, cmd_ndata_LCD_RDX, cmd_read_LCD_RDX;

// Active writer selection
writer_t active_writer;       // Використовуємо тип writer_t

// Pixel counter
reg [31:0] total_pixels;

// Instantiate writers
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
    .cmd(16'h2C00), // Pixel write command
    .data(RED), // Use input fill color
    .n(TOTAL_PIXELS), // Number of pixels in window
    .LCD_CS(cmd_ndata_LCD_CS),
    .LCD_RS(cmd_ndata_LCD_RS),
    .LCD_WR(cmd_ndata_LCD_WR),
    .LCD_RDX(cmd_ndata_LCD_RDX),
    .LCD_DATA(cmd_ndata_LCD_DATA),
    .done(cmd_ndata_done)
);

//reg read_start;
	//wire read_done;
	//wire [15:0] read_data;
//reg [15:0] lcd_id;

//lcd_read_data read_writer (
	//    .clk(lcd_clk),
	//    .reset_n(reset_n),
	//    .start(read_start),
	//    .data(read_data),
	//    .done(read_done),
	//    .LCD_CS(cmd_read_LCD_CS),
	//    .LCD_RS(cmd_read_LCD_RS),
	//    .LCD_WR(cmd_read_LCD_WR),
	//    .LCD_RDX(cmd_read_LCD_RDX),
	//    .LCD_DATA(LCD_DATA)
//);

// Multiplexer for signal selection
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
            LCD_DATA_reg = 16'hZZZZ; // High impedance for reading
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

// FSM logic
always @(posedge lcd_clk or negedge reset_n) begin
    if (!reset_n) begin
        state <= S_INIT;
        //fill_substate <= S_IDLE;
        total_pixels <= 0;
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
		//    read_start <= 0;
		//   lcd_id <= 0;
		end else begin
        case (state)
            S_INIT: begin // Wait for PLL
                if (pll_locked) begin
                    LCD_RESET_reg <= 0;
                    init_rom_addr <= 0;
                    delay_counter <= 100 * LCD_FREQ_MHZ; // 100 ms at 8 MHz
                    state <= S_RESET_LOW;
				end
			end
            S_RESET_LOW: begin // Low reset
                if (delay_counter > 0) begin
                    delay_counter <= delay_counter - 1;
					end else begin
                    LCD_RESET_reg <= 1;
                    delay_counter <= 50 * LCD_FREQ_MHZ; // 50 ms
                    state <= S_RESET_HIGH;
				end
			end
            S_RESET_HIGH: begin // High reset
                if (delay_counter > 0) begin
                    delay_counter <= delay_counter - 1;
					end else begin
                    state <= S_ROM_INIT;
				end
			end
            S_ROM_INIT: begin // ROM initialization
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
                    delay_counter <= 120 * LCD_FREQ_MHZ; // 120 ms delay
                    state <= S_DELAY;
				end
			end
            S_DELAY: begin // Delay after initialization
                if (delay_counter > 0) begin
                    delay_counter <= delay_counter - 1;
					end else begin
                    state <= S_SET_DIR;
				end
			end
            S_SET_DIR: begin // Set direction (0x3600, 0x00)
                if (!cmd_data_start) begin
                    cmd_data <= 16'h3600;
                    write_data <= 16'h00;
                    active_writer <= WRITER_CMD_DATA;
                    cmd_data_start <= 1;
					end else if (cmd_data_done) begin
                    cmd_data_start <= 0;
                    active_writer <= WRITER_NONE;
                    state <= S_FILL;
                    //fill_substate <= S_IDLE;
				end
			end
            S_FILL: begin
				state <= S_SET_XSTART_H;
			end
			S_SET_XSTART_H: begin // Set xStart high byte
				if (!cmd_data_start) begin
					cmd_data <= 16'h2A00;
					write_data <= (x_start >> 8);
					active_writer <= WRITER_CMD_DATA;
					cmd_data_start <= 1;
					end else if (cmd_data_done) begin
					cmd_data_start <= 0;
					active_writer <= WRITER_NONE;
					state <= S_SET_XSTART_L;
				end
			end
			S_SET_XSTART_L: begin // Set xStart low byte
				if (!cmd_data_start) begin
					cmd_data <= 16'h2A01;
					write_data <= (x_start & 16'hFF);
					active_writer <= WRITER_CMD_DATA;
					cmd_data_start <= 1;
					end else if (cmd_data_done) begin
					cmd_data_start <= 0;
					active_writer <= WRITER_NONE;
					state <= S_SET_XEND_H;
				end
			end
			S_SET_XEND_H: begin // Set xEnd high byte
				if (!cmd_data_start) begin
					cmd_data <= 16'h2A02;
					write_data <= (x_end >> 8);
					active_writer <= WRITER_CMD_DATA;
					cmd_data_start <= 1;
					end else if (cmd_data_done) begin
					cmd_data_start <= 0;
					active_writer <= WRITER_NONE;
					state <= S_SET_XEND_L;
				end
			end
			S_SET_XEND_L: begin // Set xEnd low byte
				if (!cmd_data_start) begin
					cmd_data <= 16'h2A03;
					write_data <= (x_end & 16'hFF);
					active_writer <= WRITER_CMD_DATA;
					cmd_data_start <= 1;
					end else if (cmd_data_done) begin
					cmd_data_start <= 0;
					active_writer <= WRITER_NONE;
					state <= S_SET_YSTART_H;
				end
			end
			S_SET_YSTART_H: begin // Set yStart high byte
				if (!cmd_data_start) begin
					cmd_data <= 16'h2B00;
					write_data <= (y_start >> 8);
					active_writer <= WRITER_CMD_DATA;
					cmd_data_start <= 1;
					end else if (cmd_data_done) begin
					cmd_data_start <= 0;
					active_writer <= WRITER_NONE;
					state <= S_SET_YSTART_L;
				end
			end
			S_SET_YSTART_L: begin // Set yStart low byte
				if (!cmd_data_start) begin
					cmd_data <= 16'h2B01;
					write_data <= (y_start & 16'hFF);
					active_writer <= WRITER_CMD_DATA;
					cmd_data_start <= 1;
					end else if (cmd_data_done) begin
					cmd_data_start <= 0;
					active_writer <= WRITER_NONE;
					state <= S_SET_YEND_H;
				end
			end
			S_SET_YEND_H: begin // Set yEnd high byte
				if (!cmd_data_start) begin
					cmd_data <= 16'h2B02;
					write_data <= (y_end >> 8);
					active_writer <= WRITER_CMD_DATA;
					cmd_data_start <= 1;
					end else if (cmd_data_done) begin
					cmd_data_start <= 0;
					active_writer <= WRITER_NONE;
					state <= S_SET_YEND_L;
				end
			end
			S_SET_YEND_L: begin // Set yEnd low byte
				if (!cmd_data_start) begin
					cmd_data <= 16'h2B03;
					write_data <= (y_end & 16'hFF);
					active_writer <= WRITER_CMD_DATA;
					cmd_data_start <= 1;
					end else if (cmd_data_done) begin
					cmd_data_start <= 0;
					active_writer <= WRITER_NONE;
					state <= S_DISPLAY_ON;
				end
			end
			S_DISPLAY_ON: begin // Enable display (0x2900)
				if (!cmd_start) begin
					cmd_data <= 16'h2900;
					active_writer <= WRITER_CMD;
					cmd_start <= 1;
					end else if (cmd_done) begin
					cmd_start <= 0;
					active_writer <= WRITER_NONE;
					state <= S_SET_ADDR;
				end
			end
			S_SET_ADDR: begin // Set address (0x2C00)
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
			S_PREP_FILL: begin // Prepare for pixel fill
				total_pixels <= ((x_end - x_start + 1) * (y_end - y_start + 1));
				state <= S_FILL_PIXELS;
			end
			S_FILL_PIXELS: begin // Fill pixels
				if (!cmd_ndata_start) begin
					active_writer <= WRITER_CMD_NDATA;
					cmd_ndata_start <= 1;
					end else if (cmd_ndata_done) begin
					cmd_ndata_start <= 0;
					active_writer <= WRITER_NONE;
					delay_counter <= 1000 * LCD_FREQ_MHZ; // 1 s delay
					state <= S_PAUSE;
				end
			end
			S_PAUSE: begin
				if (delay_counter > 0) begin
					delay_counter <= delay_counter - 1;
					end else begin
					//fill_substate <= S_IDLE;
					state <= S_BACKLIGHT;
				end
			end
		S_BACKLIGHT: begin // Backlight on
			LCD_BL_reg <= 1;
			state <= S_SET_ADDR;
			//fill_substate <= S_IDLE;
		end
		default: state <= S_INIT;
	endcase
end
end

endmodule