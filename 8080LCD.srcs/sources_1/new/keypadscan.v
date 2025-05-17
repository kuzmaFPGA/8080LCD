module keypadscan(
    input reset, 
    input clk, 
    output [3:0] row, 
    input [3:0] column, // 4-bit column for 4x4 keypad, pullup to vcc 
    output [3:0] out    // decoded output
);

    reg [3:0] row_reg;
    reg [3:0] out_reg;

assign row = row_reg;
assign out = out_reg;
    wire scan_en = &column; // Enable scanning when all columns are high

    // Scanning keypad rows
    always @(posedge clk or posedge reset)
        if (reset) 
            row_reg <= 4'b1110; // Start with first row active (low)
        else if (scan_en)
            row_reg <= {row_reg[2:0], row_reg[3]}; // Rotate rows left

    // Decode key presses
    always @(row_reg or column) begin
        out_reg = 4'b0000; // Default output
        case ({row_reg, column})
            8'b1110_1110 : out_reg = 4'b0001; // Key 1
            8'b1110_1101 : out_reg = 4'b0010; // Key 2
            8'b1110_1011 : out_reg = 4'b0011; // Key 3
            8'b1110_0111 : out_reg = 4'b1010; // Key A

            8'b1101_1110 : out_reg = 4'b0100; // Key 4
            8'b1101_1101 : out_reg = 4'b0101; // Key 5
            8'b1101_1011 : out_reg = 4'b0110; // Key 6
            8'b1101_0111 : out_reg = 4'b1011; // Key B

            8'b1011_1110 : out_reg = 4'b0111; // Key 7
            8'b1011_1101 : out_reg = 4'b1000; // Key 8
            8'b1011_1011 : out_reg = 4'b1001; // Key 9
            8'b1011_0111 : out_reg = 4'b1100; // Key C

            8'b0111_1110 : out_reg = 4'b1110; // Key E
            8'b0111_1101 : out_reg = 4'b0000; // Key 0
            8'b0111_1011 : out_reg = 4'b1111; // Key F
            8'b0111_0111 : out_reg = 4'b1101; // Key D
        endcase
    end

endmodule