`timescale 1ns / 1ps

module top_level_tb;

    // Inputs
    reg clk;
    reg reset_n;
    reg [3:0] row_data_in;
    reg ts_miso;
    reg ts_pen;

    // Outputs
    wire [3:0] col_data_out;
    wire [15:0] LCD_DATA;
    wire LCD_WR;
    wire LCD_RS;
    wire LCD_CS;
    wire LCD_RESET;
    wire LCD_BL;
    wire LCD_RDX;
    wire [7:0] la_out;
    wire led_1;
    wire ts_clk;
    wire ts_cs;
    wire ts_mosi;
    wire SDRAM_CKE;
    wire SDRAM_WEn;
    wire SDRAM_CASn;
    wire SDRAM_RASn;
    wire [12:0] SDRAM_A;
    wire [1:0] SDRAM_BA;
    wire [1:0] SDRAM_DQM;
    wire [15:0] SDRAM_DQ;

    // Instantiate the Unit Under Test (UUT)
    top_level uut (
        .clk(clk),
        .reset_n(reset_n),
        .row_data_in(row_data_in),
        .col_data_out(col_data_out),
        .LCD_DATA(LCD_DATA),
        .LCD_WR(LCD_WR),
        .LCD_RS(LCD_RS),
        .LCD_CS(LCD_CS),
        .LCD_RESET(LCD_RESET),
        .LCD_BL(LCD_BL),
        .LCD_RDX(LCD_RDX),
        .la_out(la_out),
        .led_1(led_1),
        .ts_clk(ts_clk),
        .ts_cs(ts_cs),
        .ts_miso(ts_miso),
        .ts_mosi(ts_mosi),
        .ts_pen(ts_pen)
        .SDRAM_CKE(SDRAM_CKE),
        .SDRAM_WEn(SDRAM_WEn),
        .SDRAM_CASn(SDRAM_CASn),
        .SDRAM_RASn(SDRAM_RASn),
        .SDRAM_A(SDRAM_A),
        .SDRAM_BA(SDRAM_BA),
        .SDRAM_DQM(SDRAM_DQM),
        .SDRAM_DQ(SDRAM_DQ) );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100 MHz clock (10 ns period)
    end

    // Test stimulus
    initial begin
        // Initialize Inputs
        reset_n = 0;
        //row_data_in = 4'b0000;
        //ts_miso = 0;
        //ts_pen = 1; // No touch initially

        // Reset
        #100;
        reset_n = 1;

        // Wait for initialization
        #1000;

        // Simulate keypad input
        //#100;
        //row_data_in = 4'b1010; // Simulate key press
        //#100;
        //row_data_in = 4'b0000; // Release key

        // Simulate touch input
        //#1000;
        //ts_pen = 0; // Touch detected
        //ts_miso = 1; // Simulate some touch data
        //#100;
        //ts_miso = 0;
        //#100;
        //ts_pen = 1; // Touch released

        // Wait for state transitions
        #100000;

        // Test SDRAM interface
        // Note: SDRAM_DQ is inout, so we need to handle it carefully
        // Add more specific SDRAM tests if needed

        // End simulation
        //#10000;
        $finish;
    end

    // Monitor signals
    initial begin
        $monitor("Time=%0t reset_n=%b state=%b lcd_state=%b LCD_DATA=%h LCD_WR=%b LCD_CS=%b led_1=%b",
                 $time, reset_n, uut.state, uut.lcd_state, LCD_DATA, LCD_WR, LCD_CS, led_1);
    end

    // Dump waveform
//    initial begin
//        $dumpfile("top_level_tb.vcd");
//        $dumpvars(0, top_level_tb);
//    end

endmodule