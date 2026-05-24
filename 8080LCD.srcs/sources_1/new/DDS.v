// ============================================================
// dds.v - DDS-генератор сигналів для 14-біт ЦАП @ 165 МГц
//
// wave_type:
//   2'd0 - синус (sine LUT)
//   2'd1 - прямокутні імпульси (50% duty)
//   2'd2 - трикутні
//   2'd3 - ШИМ (з налаштовуваним pwm_threshold)
//
// phase_inc обчислюється в top_module як
//   phase_inc = freq_hz * 2^32 / 165_000_000
//
// pwm_threshold у форматі 0..16383 (14-біт),
//   де 16384 = 100% duty
// ============================================================
module dds (
    input             clk,           // 165 МГц
    input             reset_n,
    input      [31:0] phase_inc,
    input      [1:0]  wave_type,
    input      [13:0] pwm_threshold, // для режиму ШИМ
    output reg [13:0] dac_out
);

reg  [31:0] phase_acc;
wire [13:0] sine_val;
reg  [13:0] tri_val;

// ── Sine LUT ──
sine_lut sine_lut_inst (
    .clk(clk),
    .idx(phase_acc[31:20]),  // старші 12 біт акумулятора
    .val(sine_val)
);

// ── Phase accumulator ──
always @(posedge clk or negedge reset_n) begin
    if (!reset_n)
        phase_acc <= 32'd0;
    else
        phase_acc <= phase_acc + phase_inc;
end

// ── Трикутний сигнал ──
// MSB phase_acc=1 - спадаюча частина (інвертуємо)
// MSB phase_acc=0 - зростаюча
always @(*) begin
    if (phase_acc[31])
        tri_val = ~phase_acc[30:17];   // 14-біт спадаючий
    else
        tri_val =  phase_acc[30:17];   // 14-біт зростаючий
end

// ── Вибір форми + регістр виходу ──
always @(posedge clk or negedge reset_n) begin
    if (!reset_n)
        dac_out <= 14'h2000; // середина шкали
    else begin
        case (wave_type)
            2'd0: dac_out <= sine_val;                                          // SINE (затримка 1 такт)
            2'd1: dac_out <= phase_acc[31] ? 14'h3FFF : 14'h0000;                // SQUARE
            2'd2: dac_out <= tri_val;                                           // TRIANGLE
            2'd3: dac_out <= (phase_acc[31:18] < pwm_threshold) ? 14'h3FFF : 14'h0000; // PWM
            default: dac_out <= 14'h2000;
        endcase
    end
end

endmodule