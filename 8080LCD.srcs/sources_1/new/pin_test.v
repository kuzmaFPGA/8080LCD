module pin_test (
    input            clk,        // системний тактовий сигнал (50 МГц)
    input            reset_n,    // активний низьким
    output           led_1,
    output           led_2,
    output           LCD_RS,
    output           LCD_CS,
    output           LCD_WR,
    output           LCD_RESET,
    output           LCD_BL,
    output    [15:0] LCD_DATA,
    output           lcd_clk
);

    // Реєстр для вихідного сигналу (50 Гц)
    reg test_signal;
    
    // Лічильник для дільника частоти
    reg [18:0] counter; // 19 біт для лічби до 500,000

    // Генерація сигналу 50 Гц
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            counter <= 0;
            test_signal <= 0;
        end else begin
            if (counter == 499_999) begin // 500,000 - 1
                counter <= 0;
                test_signal <= ~test_signal; // Перемикання сигналу
            end else begin
                counter <= counter + 1;
            end
        end
    end

    // Призначення сигналу на всі вихідні піни
    assign led_1 = test_signal;
    assign led_2 = test_signal;
    assign LCD_RS = test_signal;
    assign LCD_CS = test_signal;
    assign LCD_WR = test_signal;
    assign LCD_RESET = test_signal;
    assign LCD_BL = test_signal;
    assign LCD_DATA = {16{test_signal}}; // Усі 16 біт отримують однаковий сигнал
    assign lcd_clk = test_signal;

endmodule