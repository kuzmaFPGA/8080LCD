// ============================================================
// sine_lut.v - 4096 точок × 14-біт таблиця синусу
// Один цикл затримки (синхронний BRAM)
// ============================================================
module sine_lut (
    input         clk,
    input  [11:0] idx,    // 12-біт індекс (0..4095)
    output reg [13:0] val // 14-біт значення синусу (0..16383)
);

(* ram_style = "block" *) reg [13:0] rom [0:4095];

initial $readmemh("sine_lut.mem", rom);

always @(posedge clk) begin
    val <= rom[idx];
end

endmodule