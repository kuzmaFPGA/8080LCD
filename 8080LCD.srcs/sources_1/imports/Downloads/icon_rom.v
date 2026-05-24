// ============================================================
// icon_rom.v - 8-бітний ROM для іконок режимів DDS
// 4 іконки × 100×80 = 32000 пікселів → 4000 байт
// Кожен байт = 8 пікселів (MSB = перший)
//
// Зовнішнє адресування: 15-бітний ПІКСЕЛЬНИЙ номер (0..31999)
//   SINE     → 0    .. 7999
//   SQUARE   → 8000 .. 15999
//   TRIANGLE → 16000.. 23999
//   PWM      → 24000.. 31999
// ============================================================
module icon_rom (
    input         clk,
    input  [14:0] addr,   // піксельна адреса 0..31999
    output wire   pixel   // 1 = білий, 0 = фон
);

(* rom_style = "block" *) reg [7:0] rom [0:3999];
initial $readmemh("icon_lut.mem", rom);

// Байтова адреса і позиція біта всередині байта
wire [11:0] byte_addr = addr[14:3];  // addr / 8  (0..3999)
wire [2:0]  bit_pos   = addr[2:0];   // addr % 8

// BRAM-читання (1-тактова затримка)
reg [7:0] byte_out;
reg [2:0] bit_pos_r;

always @(posedge clk) begin
    byte_out  <= rom[byte_addr];
    bit_pos_r <= bit_pos;
end

// Комбінаційний вибір біта після BRAM (без додаткового FF)
// bit_pos=0 → MSB байта (перший піксель), bit_pos=7 → LSB
assign pixel = byte_out[7 - bit_pos_r];

endmodule