// ============================================================
// icon_rom.v — 1-бітний ROM для іконок режимів DDS
// 4 іконки × 100×80 = 32000 пікселів
// Адресація: {wave_type[1:0], pixel_index[12:0]}
//   wave_type 0 (SINE)     → addr  0 .. 7999
//   wave_type 1 (SQUARE)   → addr  8000..15999
//   wave_type 2 (TRIANGLE) → addr 16000..23999
//   wave_type 3 (PWM)      → addr 24000..31999
// ============================================================
module icon_rom (
    input             clk,
    input  [14:0]     addr,   // 0..31999
    output reg        pixel   // 1 = білий піксель іконки
);

(* rom_style = "block" *) reg rom [0:31999];
initial $readmemb("icon_lut.mem", rom);

always @(posedge clk) begin
    pixel <= rom[addr];
end

endmodule
