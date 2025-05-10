`timescale 1ns / 1ps

module mrb3973_test_tb;

    // Входи
    reg clk;
    reg reset_n;

    // Виходи
    wire [15:0] LCD_DATA;
    wire LCD_WR;
    wire LCD_RS;
    wire LCD_CS;
    wire LCD_RESET;
    wire LCD_BL;
    wire LCD_RDX;
    wire led_1;
    wire led_2;
    wire lcd_clk;
    wire     [3:0] state_out;   // Вивід стану машини станів
    wire     [9:0] init_rom_addr_out;     // Лічильник адреси
    // Інстанціювання модуля
    mrb3973_test uut (
        .clk(clk),
        .reset_n(reset_n),
        .LCD_DATA(LCD_DATA),
        .LCD_WR(LCD_WR),
        .LCD_RS(LCD_RS),
        .LCD_CS(LCD_CS),
        .LCD_RESET(LCD_RESET),
        .LCD_BL(LCD_BL),
        .LCD_RDX(LCD_RDX),
        .led_1(led_1),
        .led_2(led_2),
        .lcd_clk(lcd_clk)
//        .state_out(state_out),   // Вивід стану машини станів
 //       .init_rom_addr_out(init_rom_addr_out)     // Лічильник адреси
    );

    // Генерація тактового сигналу (50 МГц для clk, період 20 нс)
    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end

    // Імітація PLL (clk_wiz_0)
    reg pll_locked;
    reg lcd_clk_reg;
    initial begin
        pll_locked = 0;
        lcd_clk_reg = 0;
        #100 pll_locked = 1; // PLL стабілізується через 100 нс
        forever #62.5 lcd_clk_reg = ~lcd_clk_reg; // 8 МГц для lcd_clk, період 125 нс
    end
    assign lcd_clk = lcd_clk_reg;

    // Тестовий сценарій
    initial begin
        // Ініціалізація
        reset_n = 0;
        #50 reset_n = 1; // Знімаємо скид через 50 нс

        // Симуляція протягом достатнього часу для проходження ініціалізації
        #1000000000; // 10 мс

        // Перевірка ключових станів
        $display("Час: %0t, LCD_RESET: %b, LCD_BL: %b, led_1: %b, led_2: %b", $time, LCD_RESET, LCD_BL, led_1, led_2);
        $display("Час: %0t, LCD_CS: %b, LCD_RS: %b, LCD_WR: %b, LCD_DATA: %h", $time, LCD_CS, LCD_RS, LCD_WR, LCD_DATA);

        // Завершення симуляції
        #1000 $finish;
    end

    // Моніторинг сигналів
    initial begin
        $monitor("Час: %0t, State: %d, LCD_DATA: %h, LCD_RS: %b, LCD_WR: %b, LCD_CS: %b",
                 $time, state_out, LCD_DATA, LCD_RS, LCD_WR, LCD_CS);
    end

endmodule