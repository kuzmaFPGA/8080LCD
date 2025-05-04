module tb_mrb3973_test;
    reg clk, reset_n;
    wire [15:0] LCD_DATA;
    wire LCD_WR, LCD_RS, LCD_CS, LCD_RESET, LCD_BL, led_1, led_2, lcd_clk;

    mrb3973_test dut (
        .clk(clk),
        .reset_n(reset_n),
        .LCD_DATA(LCD_DATA),
        .LCD_WR(LCD_WR),
        .LCD_RS(LCD_RS),
        .LCD_CS(LCD_CS),
        .LCD_RESET(LCD_RESET),
        .LCD_BL(LCD_BL),
        .led_1(led_1),
        .led_2(led_2),
        .lcd_clk(lcd_clk)
    );

    initial begin
        clk = 0;
        reset_n = 0;
        #100 reset_n = 1;
    end

    always #10 clk = ~clk; // 50 МГц

    initial begin
        $monitor("Time=%t state=%d wr_state=%d wr_busy=%b init_rom_addr=%d LCD_WR=%b LCD_CS=%b LCD_RS=%b led_1=%b",
                 $time, dut.state, dut.wr_state, dut.wr_busy, dut.init_rom_addr, LCD_WR, LCD_CS, LCD_RS, led_1);
        #1000000 $finish;
    end
endmodule