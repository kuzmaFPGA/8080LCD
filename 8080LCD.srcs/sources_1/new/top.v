module mrb3973_test (
    input            clk,        // Системний тактовий сигнал
    input            reset_n,    // Активний низький скид
    output    [15:0] LCD_DATA,   // Шина даних LCD
    output           LCD_WR,     // WRX (write control)
    output           LCD_RS,     // D/CX (0 - команда, 1 - дані)
    output           LCD_CS,     // CSX (активний низький)
    output           LCD_RESET,  // LCD reset (низький рівень)
    output           LCD_BL,     // Підсвітка
    output           LCD_RDX,    // RDX (read control)
    output           led_1,      // LED для дебагу
    output           led_2,      // LED для PLL
    output           lcd_clk,     // Тактовий сигнал для LCD
    output     [3:0] state_out,   // Вивід стану машини станів
    output     [9:0] init_rom_addr_out     // Лічильник адреси


);

    // Регістри для вихідних сигналів
    reg    [15:0] LCD_DATA_reg;
    reg           LCD_WR_reg;
    reg           LCD_RS_reg;
    reg           LCD_CS_reg;
    reg           LCD_RESET_reg;
    reg           LCD_BL_reg;
    reg           LCD_RDX_reg;

    assign LCD_DATA = LCD_DATA_reg;
    assign LCD_WR = LCD_WR_reg;
    assign LCD_RS = LCD_RS_reg;
    assign LCD_CS = LCD_CS_reg;
    assign LCD_RESET = LCD_RESET_reg;
    assign LCD_BL = LCD_BL_reg;
    assign LCD_RDX = LCD_RDX_reg;

   // Вивід стану машини станів на піни
    assign state_out = state;
    
    reg led_1_reg;
    reg led_2_reg;
    
    wire pll_locked;

    // PLL для генерації lcd_clk (8 МГц)
    clk_wiz_0 lcd_clk_pll (
        .clk_in1(clk),
        .resetn(reset_n),
        .clk_out1(lcd_clk),
        .locked(pll_locked)
    );
    
    assign led_1 = led_1_reg;
    assign led_2 = led_2_reg;

    // ROM ініціалізації
    reg [15:0] init_rom [0:639]; // До 512 команд і даних
    reg [9:0] init_rom_addr;     // Лічильник адреси
    
    assign init_rom_addr_out = init_rom_addr;
    
    // Дані та тип для запису
    reg [15:0] cmd_data;         // Команда або дані
    reg [15:0] write_data;       // Дані для модуля cmd_data

    // Станова машина
    reg [3:0] state;

    // Лічильник затримок
    reg [31:0] delay_counter;

    // Константи кольорів (RGB565)
    parameter RED = 16'hF800;

    // Загальна кількість пікселів для 800x480 дисплея
    parameter TOTAL_PIXELS = 800 * 480;

    // Сигнали керування модулями
    reg cmd_start;               // Запуск lcd_write_cmd
    reg cmd_data_start;          // Запуск lcd_write_cmd_data
    reg cmd_ndata_start;         // Запуск lcd_write_cmd_ndata
    wire cmd_done;               // Завершення lcd_write_cmd
    wire cmd_data_done;          // Завершення lcd_write_cmd_data
    wire cmd_ndata_done;         // Завершення lcd_write_cmd_ndata

    // Вихідні сигнали модулів
    wire [15:0] cmd_LCD_DATA, cmd_data_LCD_DATA, cmd_ndata_LCD_DATA;
    wire cmd_LCD_CS, cmd_LCD_RS, cmd_LCD_WR, cmd_LCD_RDX;
    wire cmd_data_LCD_CS, cmd_data_LCD_RS, cmd_data_LCD_WR, cmd_data_LCD_RDX;
    wire cmd_ndata_LCD_CS, cmd_ndata_LCD_RS, cmd_ndata_LCD_WR, cmd_ndata_LCD_RDX;

    // Вибір активного модуля
    reg [1:0] active_writer;     // 0 - none, 1 - cmd, 2 - cmd_data, 3 - cmd_ndata
    localparam WRITER_NONE = 2'd0, WRITER_CMD = 2'd1, WRITER_CMD_DATA = 2'd2, WRITER_CMD_NDATA = 2'd3;

    // Лічильник пікселів
    reg [31:0] pixel_cnt;

    // Інстанціювання модулів
    lcd_write_cmd cmd_writer (
        .clk(lcd_clk),
        .reset_n(reset_n),
        .start(cmd_start),
        .cmd(cmd_data),
        .LCD_CS(cmd_LCD_CS),
        .LCD_RS(cmd_LCD_RS),
        .LCD_WR(cmd_LCD_WR),
        .LCD_RDX(cmd_LCD_RDX),
        .LCD_DATA(cmd_LCD_DATA),
        .done(cmd_done)
    );

    lcd_write_cmd_data cmd_data_writer (
        .clk(lcd_clk),
        .reset_n(reset_n),
        .start(cmd_data_start),
        .cmd(cmd_data),
        .data(write_data),
        .LCD_CS(cmd_data_LCD_CS),
        .LCD_RS(cmd_data_LCD_RS),
        .LCD_WR(cmd_data_LCD_WR),
        .LCD_RDX(cmd_data_LCD_RDX),
        .LCD_DATA(cmd_data_LCD_DATA),
        .done(cmd_data_done)
    );

    lcd_write_cmd_ndata cmd_ndata_writer (
        .clk(lcd_clk),
        .reset_n(reset_n),
        .start(cmd_ndata_start),
        .cmd(16'h2C00), // Команда для запису пікселів
        .data(RED),    // Червоний колір
        .n(TOTAL_PIXELS),
        .LCD_CS(cmd_ndata_LCD_CS),
        .LCD_RS(cmd_ndata_LCD_RS),
        .LCD_WR(cmd_ndata_LCD_WR),
        .LCD_RDX(cmd_ndata_LCD_RDX),
        .LCD_DATA(cmd_ndata_LCD_DATA),
        .done(cmd_ndata_done)
    );

    // Мультиплексор для вибору вихідних сигналів
    always @(*) begin
        case (active_writer)
            WRITER_CMD: begin
                LCD_CS_reg = cmd_LCD_CS;
                LCD_RS_reg = cmd_LCD_RS;
                LCD_WR_reg = cmd_LCD_WR;
                LCD_RDX_reg = cmd_LCD_RDX;
                LCD_DATA_reg = cmd_LCD_DATA;
                led_1_reg <= 0;
                led_2_reg <= 0;
            end
            WRITER_CMD_DATA: begin
                LCD_CS_reg = cmd_data_LCD_CS;
                LCD_RS_reg = cmd_data_LCD_RS;
                LCD_WR_reg = cmd_data_LCD_WR;
                LCD_RDX_reg = cmd_data_LCD_RDX;
                LCD_DATA_reg = cmd_data_LCD_DATA;
                led_1_reg <= 0;
                led_2_reg <= 1;
            end
            WRITER_CMD_NDATA: begin
                LCD_CS_reg = cmd_ndata_LCD_CS;
                LCD_RS_reg = cmd_ndata_LCD_RS;
                LCD_WR_reg = cmd_ndata_LCD_WR;
                LCD_RDX_reg = cmd_ndata_LCD_RDX;
                LCD_DATA_reg = cmd_ndata_LCD_DATA;
                led_1_reg <= 1;
                led_2_reg <= 0;
            end
            default: begin
                LCD_CS_reg = 1;
                LCD_RS_reg = 0;
                LCD_WR_reg = 1;
                LCD_RDX_reg = 1;
                LCD_DATA_reg = 16'bz;
                led_1_reg <= 1;
                led_2_reg <= 1;
            end
        endcase
    end

    // Ініціалізація ROM (без змін)
    initial begin
		init_rom[0] =  16'hF000;     init_rom[1] =  16'h0055;
        init_rom[2] =  16'hF001;     init_rom[3] =  16'h00AA;
        init_rom[4] =  16'hF002;     init_rom[5] =  16'h0052;
        init_rom[6] =  16'hF003;     init_rom[7] =  16'h0008;
        init_rom[8] =  16'hF004;     init_rom[9] =  16'h0001;
        init_rom[10] =  16'hB600;    init_rom[11] =  16'h0034;
        init_rom[12] =  16'hB601;    init_rom[13] =  16'h0034;
        init_rom[14] =  16'hB602;    init_rom[15] =  16'h0034;
        init_rom[16] =  16'hB000;    init_rom[17] =  16'h000D;
        init_rom[18] =  16'hB001;    init_rom[19] =  16'h000D;
        init_rom[20] =  16'hB002;    init_rom[21] =  16'h000D;
        init_rom[22] =  16'hB700;    init_rom[23] =  16'h0024;
        init_rom[24] =  16'hB701;    init_rom[25] =  16'h0024;
        init_rom[26] =  16'hB702;    init_rom[27] =  16'h0024;
        init_rom[28] =  16'hB100;    init_rom[29] =  16'h000D;
        init_rom[30] =  16'hB101;    init_rom[31] =  16'h000D;
        init_rom[32] =  16'hB102;    init_rom[33] =  16'h000D;
        init_rom[34] =  16'hB800;    init_rom[35] =  16'h0024;
        init_rom[36] =  16'hB801;    init_rom[37] =  16'h0024;
        init_rom[38] =  16'hB802;    init_rom[39] =  16'h0024;
        init_rom[40] =  16'hB200;    init_rom[41] =  16'h0000;
        init_rom[42] =  16'hB900;    init_rom[43] =  16'h0024;
        init_rom[44] =  16'hB901;    init_rom[45] =  16'h0024;
        init_rom[46] =  16'hB902;    init_rom[47] =  16'h0024;
        init_rom[48] =  16'hB300;    init_rom[49] =  16'h0005;
        init_rom[50] =  16'hB301;    init_rom[51] =  16'h0005;
        init_rom[52] =  16'hB302;    init_rom[53] =  16'h0005;
        init_rom[54] =  16'hBA00;    init_rom[55] =  16'h0034;
        init_rom[56] =  16'hBA01;    init_rom[57] =  16'h0034;
        init_rom[58] =  16'hBA02;    init_rom[59] =  16'h0034;
        init_rom[60] =  16'hB500;    init_rom[61] =  16'h000B;
        init_rom[62] =  16'hB501;    init_rom[63] =  16'h000B;
        init_rom[64] =  16'hB502;    init_rom[65] =  16'h000B;
        init_rom[66] =  16'hBC00;    init_rom[67] =  16'h0000;
        init_rom[68] =  16'hBC01;    init_rom[69] =  16'h00A3;
        init_rom[70] =  16'hBC02;    init_rom[71] =  16'h0000;
        init_rom[72] =  16'hBD00;    init_rom[73] =  16'h0000;
        init_rom[74] =  16'hBD01;    init_rom[75] =  16'h00A3;
        init_rom[76] =  16'hBD02;    init_rom[77] =  16'h0000;
        init_rom[78] =  16'hBE00;    init_rom[79] =  16'h0000;
        init_rom[80] =  16'hBE01;    init_rom[81] =  16'h0063;
        init_rom[82] =  16'hD100;    init_rom[83] =  16'h0000;
        init_rom[84] =  16'hD101;    init_rom[85] =  16'h0037;
        init_rom[86] =  16'hD102;    init_rom[87] =  16'h0000;
        init_rom[88] =  16'hD103;    init_rom[89] =  16'h0052;
        init_rom[90] =  16'hD104;    init_rom[91] =  16'h0000;
        init_rom[92] =  16'hD105;    init_rom[93] =  16'h007B;
        init_rom[94] =  16'hD106;    init_rom[95] =  16'h0000;
        init_rom[96] =  16'hD107;    init_rom[97] =  16'h0099;
        init_rom[98] =  16'hD108;    init_rom[99] =  16'h0000;
        init_rom[100] =  16'hD109;   init_rom[101] =  16'h00B1;
        init_rom[102] =  16'hD10A;   init_rom[103] =  16'h0000;
        init_rom[104] =  16'hD10B;   init_rom[105] =  16'h00D2;
        init_rom[106] =  16'hD10C;   init_rom[107] =  16'h0000;
        init_rom[108] =  16'hD10D;   init_rom[109] =  16'h00F6;
        init_rom[110] =  16'hD10E;   init_rom[111] =  16'h0001;
        init_rom[112] =  16'hD10F;   init_rom[113] =  16'h0027;
        init_rom[114] =  16'hD110;   init_rom[115] =  16'h0001;
        init_rom[116] =  16'hD111;   init_rom[117] =  16'h004E;
        init_rom[118] =  16'hD112;   init_rom[119] =  16'h0001;
        init_rom[120] =  16'hD113;   init_rom[121] =  16'h008C;
        init_rom[122] =  16'hD114;   init_rom[123] =  16'h0001;
        init_rom[124] =  16'hD115;   init_rom[125] =  16'h00BE;
        init_rom[126] =  16'hD116;   init_rom[127] =  16'h0002;
        init_rom[128] =  16'hD117;   init_rom[129] =  16'h000B;
        init_rom[130] =  16'hD118;   init_rom[131] =  16'h0002;
        init_rom[132] =  16'hD119;   init_rom[133] =  16'h0048;
        init_rom[134] =  16'hD11A;   init_rom[135] =  16'h0002;
        init_rom[136] =  16'hD11B;   init_rom[137] =  16'h004A;
        init_rom[138] =  16'hD11C;   init_rom[139] =  16'h0002;
        init_rom[140] =  16'hD11D;   init_rom[141] =  16'h007E;
        init_rom[142] =  16'hD11E;   init_rom[143] =  16'h0002;
        init_rom[144] =  16'hD11F;   init_rom[145] =  16'h00BC;
        init_rom[146] =  16'hD120;   init_rom[147] =  16'h0002;
        init_rom[148] =  16'hD121;   init_rom[149] =  16'h00E1;
        init_rom[150] =  16'hD122;   init_rom[151] =  16'h0003;
        init_rom[152] =  16'hD123;   init_rom[153] =  16'h0010;
        init_rom[154] =  16'hD124;   init_rom[155] =  16'h0003;
        init_rom[156] =  16'hD125;   init_rom[157] =  16'h0031;
        init_rom[158] =  16'hD126;   init_rom[159] =  16'h0003;
        init_rom[160] =  16'hD127;   init_rom[161] =  16'h005A;
        init_rom[162] =  16'hD128;   init_rom[163] =  16'h0003;
        init_rom[164] =  16'hD129;   init_rom[165] =  16'h0073;
        init_rom[166] =  16'hD12A;   init_rom[167] =  16'h0003;
        init_rom[168] =  16'hD12B;   init_rom[169] =  16'h0094;
        init_rom[170] =  16'hD12C;   init_rom[171] =  16'h0003;
        init_rom[172] =  16'hD12D;   init_rom[173] =  16'h009F;
        init_rom[174] =  16'hD12E;   init_rom[175] =  16'h0003;
        init_rom[176] =  16'hD12F;   init_rom[177] =  16'h00B3;
        init_rom[178] =  16'hD130;   init_rom[179] =  16'h0003;
        init_rom[180] =  16'hD131;   init_rom[181] =  16'h00B9;
        init_rom[182] =  16'hD132;   init_rom[183] =  16'h0003;
        init_rom[184] =  16'hD133;   init_rom[185] =  16'h00C1;
        init_rom[186] =  16'hD200;   init_rom[187] =  16'h0000;
        init_rom[188] =  16'hD201;   init_rom[189] =  16'h0037;
        init_rom[190] =  16'hD202;   init_rom[191] =  16'h0000;
        init_rom[192] =  16'hD203;   init_rom[193] =  16'h0052;
        init_rom[194] =  16'hD204;   init_rom[195] =  16'h0000;
        init_rom[196] =  16'hD205;   init_rom[197] =  16'h007B;
        init_rom[198] =  16'hD206;   init_rom[199] =  16'h0000;
        init_rom[200] =  16'hD207;   init_rom[201] =  16'h0099;
        init_rom[202] =  16'hD208;   init_rom[203] =  16'h0000;
        init_rom[204] =  16'hD209;   init_rom[205] =  16'h00B1;
        init_rom[206] =  16'hD20A;   init_rom[207] =  16'h0000;
        init_rom[208] =  16'hD20B;   init_rom[209] =  16'h00D2;
        init_rom[210] =  16'hD20C;   init_rom[211] =  16'h0000;
        init_rom[212] =  16'hD20D;   init_rom[213] =  16'h00F6;
        init_rom[214] =  16'hD20E;   init_rom[215] =  16'h0001;
        init_rom[216] =  16'hD20F;   init_rom[217] =  16'h0027;
        init_rom[218] =  16'hD210;   init_rom[219] =  16'h0001;
        init_rom[220] =  16'hD211;   init_rom[221] =  16'h004E;
        init_rom[222] =  16'hD212;   init_rom[223] =  16'h0001;
        init_rom[224] =  16'hD213;   init_rom[225] =  16'h008C;
        init_rom[226] =  16'hD214;   init_rom[227] =  16'h0001;
        init_rom[228] =  16'hD215;   init_rom[229] =  16'h00BE;
        init_rom[230] =  16'hD216;   init_rom[231] =  16'h0002;
        init_rom[232] =  16'hD217;   init_rom[233] =  16'h000B;
        init_rom[234] =  16'hD218;   init_rom[235] =  16'h0002;
        init_rom[236] =  16'hD219;   init_rom[237] =  16'h0048;
        init_rom[238] =  16'hD21A;   init_rom[239] =  16'h0002;
        init_rom[240] =  16'hD21B;   init_rom[241] =  16'h004A;
        init_rom[242] =  16'hD21C;   init_rom[243] =  16'h0002;
        init_rom[244] =  16'hD21D;   init_rom[245] =  16'h007E;
        init_rom[246] =  16'hD21E;   init_rom[247] =  16'h0002;
        init_rom[248] =  16'hD21F;   init_rom[249] =  16'h00BC;
        init_rom[250] =  16'hD220;   init_rom[251] =  16'h0002;
        init_rom[252] =  16'hD221;   init_rom[253] =  16'h00E1;
        init_rom[254] =  16'hD222;   init_rom[255] =  16'h0003;
        init_rom[256] =  16'hD223;   init_rom[257] =  16'h0010;
        init_rom[258] =  16'hD224;   init_rom[259] =  16'h0003;
        init_rom[260] =  16'hD225;   init_rom[261] =  16'h0031;
        init_rom[262] =  16'hD226;   init_rom[263] =  16'h0003;
        init_rom[264] =  16'hD227;   init_rom[265] =  16'h005A;
        init_rom[266] =  16'hD228;   init_rom[267] =  16'h0003;
        init_rom[268] =  16'hD229;   init_rom[269] =  16'h0073;
        init_rom[270] =  16'hD22A;   init_rom[271] =  16'h0003;
        init_rom[272] =  16'hD22B;   init_rom[273] =  16'h0094;
        init_rom[274] =  16'hD22C;   init_rom[275] =  16'h0003;
        init_rom[276] =  16'hD22D;   init_rom[277] =  16'h009F;
        init_rom[278] =  16'hD22E;   init_rom[279] =  16'h0003;
        init_rom[280] =  16'hD22F;   init_rom[281] =  16'h00B3;
        init_rom[282] =  16'hD230;   init_rom[283] =  16'h0003;
        init_rom[284] =  16'hD231;   init_rom[285] =  16'h00B9;
        init_rom[286] =  16'hD232;   init_rom[287] =  16'h0003;
        init_rom[288] =  16'hD233;   init_rom[289] =  16'h00C1;
        init_rom[290] =  16'hD300;   init_rom[291] =  16'h0000;
        init_rom[292] =  16'hD301;   init_rom[293] =  16'h0037;
        init_rom[294] =  16'hD302;   init_rom[295] =  16'h0000;
        init_rom[296] =  16'hD303;   init_rom[297] =  16'h0052;
        init_rom[298] =  16'hD304;   init_rom[299] =  16'h0000;
        init_rom[300] =  16'hD305;   init_rom[301] =  16'h007B;
        init_rom[302] =  16'hD306;   init_rom[303] =  16'h0000;
        init_rom[304] =  16'hD307;   init_rom[305] =  16'h0099;
        init_rom[306] =  16'hD308;   init_rom[307] =  16'h0000;
        init_rom[308] =  16'hD309;   init_rom[309] =  16'h00B1;
        init_rom[310] =  16'hD30A;   init_rom[311] =  16'h0000;
        init_rom[312] =  16'hD30B;   init_rom[313] =  16'h00D2;
        init_rom[314] =  16'hD30C;   init_rom[315] =  16'h0000;
        init_rom[316] =  16'hD30D;   init_rom[317] =  16'h00F6;
        init_rom[318] =  16'hD30E;   init_rom[319] =  16'h0001;
        init_rom[320] =  16'hD30F;   init_rom[321] =  16'h0027;
        init_rom[322] =  16'hD310;   init_rom[323] =  16'h0001;
        init_rom[324] =  16'hD311;   init_rom[325] =  16'h004E;
        init_rom[326] =  16'hD312;   init_rom[327] =  16'h0001;
        init_rom[328] =  16'hD313;   init_rom[329] =  16'h008C;
        init_rom[330] =  16'hD314;   init_rom[331] =  16'h0001;
        init_rom[332] =  16'hD315;   init_rom[333] =  16'h00BE;
        init_rom[334] =  16'hD316;   init_rom[335] =  16'h0002;
        init_rom[336] =  16'hD317;   init_rom[337] =  16'h000B;
        init_rom[338] =  16'hD318;   init_rom[339] =  16'h0002;
        init_rom[340] =  16'hD319;   init_rom[341] =  16'h0048;
        init_rom[342] =  16'hD31A;   init_rom[343] =  16'h0002;
        init_rom[344] =  16'hD31B;   init_rom[345] =  16'h004A;
        init_rom[346] =  16'hD31C;   init_rom[347] =  16'h0002;
        init_rom[348] =  16'hD31D;   init_rom[349] =  16'h007E;
        init_rom[350] =  16'hD31E;   init_rom[351] =  16'h0002;
        init_rom[352] =  16'hD31F;   init_rom[353] =  16'h00BC;
        init_rom[354] =  16'hD320;   init_rom[355] =  16'h0002;
        init_rom[356] =  16'hD321;   init_rom[357] =  16'h00E1;
        init_rom[358] =  16'hD322;   init_rom[359] =  16'h0003;
        init_rom[360] =  16'hD323;   init_rom[361] =  16'h0010;
        init_rom[362] =  16'hD324;   init_rom[363] =  16'h0003;
        init_rom[364] =  16'hD325;   init_rom[365] =  16'h0031;
        init_rom[366] =  16'hD326;   init_rom[367] =  16'h0003;
        init_rom[368] =  16'hD327;   init_rom[369] =  16'h005A;
        init_rom[370] =  16'hD328;   init_rom[371] =  16'h0003;
        init_rom[372] =  16'hD329;   init_rom[373] =  16'h0073;
        init_rom[374] =  16'hD32A;   init_rom[375] =  16'h0003;
        init_rom[376] =  16'hD32B;   init_rom[377] =  16'h0094;
        init_rom[378] =  16'hD32C;   init_rom[379] =  16'h0003;
        init_rom[380] =  16'hD32D;   init_rom[381] =  16'h009F;
        init_rom[382] =  16'hD32E;   init_rom[383] =  16'h0003;
        init_rom[384] =  16'hD32F;   init_rom[385] =  16'h00B3;
        init_rom[386] =  16'hD330;   init_rom[387] =  16'h0003;
        init_rom[388] =  16'hD331;   init_rom[389] =  16'h00B9;
        init_rom[390] =  16'hD332;   init_rom[391] =  16'h0003;
        init_rom[392] =  16'hD333;   init_rom[393] =  16'h00C1;
        init_rom[394] =  16'hD400;   init_rom[395] =  16'h0000;
        init_rom[396] =  16'hD401;   init_rom[397] =  16'h0037;
        init_rom[398] =  16'hD402;   init_rom[399] =  16'h0000;
        init_rom[400] =  16'hD403;   init_rom[401] =  16'h0052;
        init_rom[402] =  16'hD404;   init_rom[403] =  16'h0000;
        init_rom[404] =  16'hD405;   init_rom[405] =  16'h007B;
        init_rom[406] =  16'hD406;   init_rom[407] =  16'h0000;
        init_rom[408] =  16'hD407;   init_rom[409] =  16'h0099;
        init_rom[410] =  16'hD408;   init_rom[411] =  16'h0000;
        init_rom[412] =  16'hD409;   init_rom[413] =  16'h00B1;
        init_rom[414] =  16'hD40A;   init_rom[415] =  16'h0000;
        init_rom[416] =  16'hD40B;   init_rom[417] =  16'h00D2;
        init_rom[418] =  16'hD40C;   init_rom[419] =  16'h0000;
        init_rom[420] =  16'hD40D;   init_rom[421] =  16'h00F6;
        init_rom[422] =  16'hD40E;   init_rom[423] =  16'h0001;
        init_rom[424] =  16'hD40F;   init_rom[425] =  16'h0027;
        init_rom[426] =  16'hD410;   init_rom[427] =  16'h0001;
        init_rom[428] =  16'hD411;   init_rom[429] =  16'h004E;
        init_rom[430] =  16'hD412;   init_rom[431] =  16'h0001;
        init_rom[432] =  16'hD413;   init_rom[433] =  16'h008C;
        init_rom[434] =  16'hD414;   init_rom[435] =  16'h0001;
        init_rom[436] =  16'hD415;   init_rom[437] =  16'h00BE;
        init_rom[438] =  16'hD416;   init_rom[439] =  16'h0002;
        init_rom[440] =  16'hD417;   init_rom[441] =  16'h000B;
        init_rom[442] =  16'hD418;   init_rom[443] =  16'h0002;
        init_rom[444] =  16'hD419;   init_rom[445] =  16'h0048;
        init_rom[446] =  16'hD41A;   init_rom[447] =  16'h0002;
        init_rom[448] =  16'hD41B;   init_rom[449] =  16'h004A;
        init_rom[450] =  16'hD41C;   init_rom[451] =  16'h0002;
        init_rom[452] =  16'hD41D;   init_rom[453] =  16'h007E;
        init_rom[454] =  16'hD41E;   init_rom[455] =  16'h0002;
        init_rom[456] =  16'hD41F;   init_rom[457] =  16'h00BC;
        init_rom[458] =  16'hD420;   init_rom[459] =  16'h0002;
        init_rom[460] =  16'hD421;   init_rom[461] =  16'h00E1;
        init_rom[462] =  16'hD422;   init_rom[463] =  16'h0003;
        init_rom[464] =  16'hD423;   init_rom[465] =  16'h0010;
        init_rom[466] =  16'hD424;   init_rom[467] =  16'h0003;
        init_rom[468] =  16'hD425;   init_rom[469] =  16'h0031;
        init_rom[470] =  16'hD426;   init_rom[471] =  16'h0003;
        init_rom[472] =  16'hD427;   init_rom[473] =  16'h005A;
        init_rom[474] =  16'hD428;   init_rom[475] =  16'h0003;
        init_rom[476] =  16'hD429;   init_rom[477] =  16'h0073;
        init_rom[478] =  16'hD42A;   init_rom[479] =  16'h0003;
        init_rom[480] =  16'hD42B;   init_rom[481] =  16'h0094;
        init_rom[482] =  16'hD42C;   init_rom[483] =  16'h0003;
        init_rom[484] =  16'hD42D;   init_rom[485] =  16'h009F;
        init_rom[486] =  16'hD42E;   init_rom[487] =  16'h0003;
        init_rom[488] =  16'hD42F;   init_rom[489] =  16'h00B3;
        init_rom[490] =  16'hD430;   init_rom[491] =  16'h0003;
        init_rom[492] =  16'hD431;   init_rom[493] =  16'h00B9;
        init_rom[494] =  16'hD432;   init_rom[495] =  16'h0003;
        init_rom[496] =  16'hD433;   init_rom[497] =  16'h00C1;
        init_rom[498] =  16'hD434;   init_rom[499] =  16'h0003;
        init_rom[500] =  16'hD435;   init_rom[501] =  16'h00D2;
        init_rom[502] =  16'hD436;   init_rom[503] =  16'h0003;
        init_rom[504] =  16'hD437;   init_rom[505] =  16'h00E3;
        init_rom[506] =  16'hD438;   init_rom[507] =  16'h0003;
        init_rom[508] =  16'hD439;   init_rom[509] =  16'h00F5;
        init_rom[510] =  16'hD43A;   init_rom[511] =  16'h0003;
        init_rom[512] =  16'hD43B;   init_rom[513] =  16'h00FF;
        init_rom[514] =  16'hD43C;   init_rom[515] =  16'h0000;
        init_rom[516] =  16'hD43D;   init_rom[517] =  16'h0017;
        init_rom[518] =  16'hD43E;   init_rom[519] =  16'h0000;
        init_rom[520] =  16'hD43F;   init_rom[521] =  16'h0037;
        init_rom[522] =  16'hD440;   init_rom[523] =  16'h0000;
        init_rom[524] =  16'hD441;   init_rom[525] =  16'h0052;
        init_rom[526] =  16'hD442;   init_rom[527] =  16'h0000;
        init_rom[528] =  16'hD443;   init_rom[529] =  16'h007B;
        init_rom[530] =  16'hD444;   init_rom[531] =  16'h0000;
        init_rom[532] =  16'hD445;   init_rom[533] =  16'h0099;
        init_rom[534] =  16'hD446;   init_rom[535] =  16'h0000;
        init_rom[536] =  16'hD447;   init_rom[537] =  16'h00B1;
        init_rom[538] =  16'hD448;   init_rom[539] =  16'h0000;
        init_rom[540] =  16'hD449;   init_rom[541] =  16'h00D2;
        init_rom[542] =  16'hD44A;   init_rom[543] =  16'h0000;
        init_rom[544] =  16'hD44B;   init_rom[545] =  16'h00F6;
        init_rom[546] =  16'hD44C;   init_rom[547] =  16'h0001;
        init_rom[548] =  16'hD44D;   init_rom[549] =  16'h0027;
        init_rom[550] =  16'hD44E;   init_rom[551] =  16'h0001;
        init_rom[552] =  16'hD44F;   init_rom[553] =  16'h004E;
        init_rom[554] =  16'hD450;   init_rom[555] =  16'h0001;
        init_rom[556] =  16'hD451;   init_rom[557] =  16'h008C;
        init_rom[558] =  16'hD452;   init_rom[559] =  16'h0001;
        init_rom[560] =  16'hD453;   init_rom[561] =  16'h00BE;
        init_rom[562] =  16'hD454;   init_rom[563] =  16'h0002;
        init_rom[564] =  16'hD455;   init_rom[565] =  16'h000B;
        init_rom[566] =  16'hD456;   init_rom[567] =  16'h0002;
        init_rom[568] =  16'hD457;   init_rom[569] =  16'h0048;
        init_rom[570] =  16'hD458;   init_rom[571] =  16'h0002;
        init_rom[572] =  16'hD459;   init_rom[573] =  16'h004A;
        init_rom[574] =  16'hD45A;   init_rom[575] =  16'h0002;
        init_rom[576] =  16'hD45B;   init_rom[577] =  16'h007E;
        init_rom[578] =  16'hD45C;   init_rom[579] =  16'h0002;
        init_rom[580] =  16'hD45D;   init_rom[581] =  16'h00BC;
        init_rom[582] =  16'hD45E;   init_rom[583] =  16'h0002;
        init_rom[584] =  16'hD45F;   init_rom[585] =  16'h00E1;
        init_rom[586] =  16'hD460;   init_rom[587] =  16'h0003;
        init_rom[588] =  16'hD461;   init_rom[589] =  16'h0010;
        init_rom[590] =  16'hD462;   init_rom[591] =  16'h0003;
        init_rom[592] =  16'hD463;   init_rom[593] =  16'h0031;
        init_rom[594] =  16'hD464;   init_rom[595] =  16'h0003;
        init_rom[596] =  16'hD465;   init_rom[597] =  16'h005A;
        init_rom[598] =  16'hD466;   init_rom[599] =  16'h0003;
        init_rom[600] =  16'hD467;   init_rom[601] =  16'h0073;
        init_rom[602] =  16'hD468;   init_rom[603] =  16'h0003;
        init_rom[604] =  16'hD469;   init_rom[605] =  16'h0094;
        init_rom[606] =  16'hD46A;   init_rom[607] =  16'h0003;
        init_rom[608] =  16'hD46B;   init_rom[609] =  16'h009F;
        init_rom[610] =  16'hD46C;   init_rom[611] =  16'h0003;
        init_rom[612] =  16'hD46D;   init_rom[613] =  16'h00B3;
        init_rom[614] =  16'hD46E;   init_rom[615] =  16'h0003;
        init_rom[616] =  16'hD46F;   init_rom[617] =  16'h00B9;
        init_rom[618] =  16'hD470;   init_rom[619] =  16'h0003;
        init_rom[620] =  16'hD471;   init_rom[621] =  16'h00C1;
        init_rom[622] =  16'hD472;   init_rom[623] =  16'h0003;
        init_rom[624] =  16'hD473;   init_rom[625] =  16'h00D2;
        init_rom[626] =  16'hD474;   init_rom[627] =  16'h0003;
        init_rom[628] =  16'hD475;   init_rom[629] =  16'h00E3;
        init_rom[630] =  16'hD476;   init_rom[631] =  16'h0003;
        init_rom[632] =  16'hD477;   init_rom[633] =  16'h00F5;
        init_rom[634] =  16'hD478;   init_rom[635] =  16'h0003;
        init_rom[636] =  16'hD479;   init_rom[637] =  16'h00FF;
    end

    // Логіка FSM
    always @(posedge lcd_clk or negedge reset_n) begin
        if (!reset_n) begin
            state <= 0;
            pixel_cnt <= 0;
            LCD_RESET_reg <= 0;
            init_rom_addr <= 0;
            delay_counter <= 0;
            cmd_start <= 0;
            cmd_data_start <= 0;
            cmd_ndata_start <= 0;
            active_writer <= WRITER_NONE;
            cmd_data <= 0;
            write_data <= 0;
        end else begin
            case (state)
                0: begin // Очікування PLL
                    if (pll_locked) begin
                        LCD_RESET_reg <= 0;
                        LCD_BL_reg <= 1;
                        init_rom_addr <= 0;
                        delay_counter <= 2 * 8000; // 2 мс при 8 МГц
                        state <= 7;
                    end
                end
                7: begin // Затримка ресету
                    if (delay_counter > 0) begin
                        delay_counter <= delay_counter - 1;
                    end else begin
                        LCD_RESET_reg <= 1;
                        state <= 2;
                    end
                end
                2: begin // Ініціалізація з ROM
                    if (init_rom_addr <= 636) begin
                        if (!cmd_data_start) begin
                                cmd_data <= init_rom[init_rom_addr][15:0];
                                write_data <= init_rom[init_rom_addr + 1][15:0];
                                active_writer <= WRITER_CMD_DATA;
                                cmd_data_start <= 1;
                            end else if (cmd_data_done) begin
                                cmd_data_start <= 0;
                                active_writer <= WRITER_NONE;
                                init_rom_addr <= init_rom_addr + 2;
                            end
                        end
                     else begin
                        delay_counter <= 120 * 8000; // 120 мс затримка
                        state <= 8;
                    end
                end
                8: begin // Затримка після ініціалізації
                    if (delay_counter > 0) begin
                        delay_counter <= delay_counter - 1;
                    end else begin
                        state <= 3;
                    end
                end
                3: begin // Увімкнення дисплея (команда 0x2900)
                    if (!cmd_start) begin
                        cmd_data <= 16'h2900;
                        active_writer <= WRITER_CMD;
                        cmd_start <= 1;
                    end else if (cmd_done) begin
                        cmd_start <= 0;
                        active_writer <= WRITER_NONE;
                        state <= 9;
                    end
                end
                9: begin // Перехід до наступного стану
                    state <= 4;
                end
                4: begin // Встановлення адреси (команда 0x2C00)
                    if (!cmd_start) begin
                        cmd_data <= 16'h2C00;
                        active_writer <= WRITER_CMD;
                        cmd_start <= 1;
                    end else if (cmd_done) begin
                        cmd_start <= 0;
                        active_writer <= WRITER_NONE;
                        state <= 10;
                    end
                end
                10: begin // Підготовка до заповнення пікселів
                    pixel_cnt <= 0;
                    state <= 5;
                end
                5: begin // Заповнення пікселів
                    if (!cmd_ndata_start) begin
                        active_writer <= WRITER_CMD_NDATA;
                        cmd_ndata_start <= 1;
                    end else if (cmd_ndata_done) begin
                        cmd_ndata_start <= 0;
                        active_writer <= WRITER_NONE;
                        state <= 6;
                    end
                end
                6: begin 

                end
                default: state <= 0;
            endcase
        end
    end

endmodule

