`timescale 1ns / 1ps

module top_level_tb;

    // Inputs
    reg clk;
    reg reset_n;

    // Outputs
    wire [3:0] col_data_out;
    wire [15:0] LCD_DATA;
    wire LCD_WR;
    wire LCD_RS;
    wire LCD_CS;
    wire LCD_RESET;
    wire LCD_BL;
    wire LCD_RDX;
    wire [2:0]state;
    wire [31:0]data_count;


    // Instantiate the Unit Under Test (UUT)
    top_level uut (
        .clk(clk),
        .reset_n(reset_n),
        .LCD_DATA(LCD_DATA),
        .LCD_WR(LCD_WR),
        .LCD_RS(LCD_RS),
        .LCD_CS(LCD_CS),
        .LCD_RESET(LCD_RESET),
        .LCD_BL(LCD_BL),
        .LCD_RDX(LCD_RDX),
        .state(state),
        .data_count(data_count)
);
    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100 MHz clock (10 ns period)
    end

    // Test stimulus
    initial begin
        // Initialize Inputs
        reset_n = 0;

        // Reset
        #10;
        reset_n = 1;

        // Wait for initialization
        #10;


        // Wait for state transitions
        #4000000;

        // Test SDRAM interface
        // Note: SDRAM_DQ is inout, so we need to handle it carefully
        // Add more specific SDRAM tests if needed

        // End simulation
        //#10000;
        $finish;
    end

    // Monitor signals
    initial begin
        $monitor("Time=%0t reset_n=%b state=%b lcd_state=%b LCD_DATA=%h LCD_WR=%b LCD_CS=%b",
                 $time, reset_n, uut.state, uut.lcd_state, LCD_DATA, LCD_WR, LCD_CS);
    end

    // Dump waveform
//    initial begin
//        $dumpfile("top_level_tb.vcd");
//        $dumpvars(0, top_level_tb);
//    end

endmodule