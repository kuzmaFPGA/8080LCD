module mrb3973_test (
    input        clk,        // системний тактовий сигнал
    input        reset_n,    // активний низьким
    output reg [15:0] LCD_DATA,
    output reg       LCD_WR,
    output reg       LCD_RS,
    output reg       LCD_CS,
    output reg       LCD_RESET,
    output           led_1,
    output           led_2
);

// ROM ініціалізації
reg [17:0] init_rom [0:639]; // до 512 команд і даних
reg [9:0] init_rom_addr;     // лічильник адреси
wire [17:0] init_rom_data = init_rom[init_rom_addr];

// Розшифровка
wire is_data = init_rom_data[17];
wire [15:0] cmd_data = init_rom_data[15:0];

    // Станова машина
    reg [3:0] state;
    reg [23:0] delay_cnt;
    
    reg [31:0] delay_counter;
    reg        delay_active;

    // Константи кольорів (RGB565)
    parameter RED   = 16'hF800;

    // Лічильник пікселів
    reg [31:0] pixel_cnt;

    // Загальна кількість пікселів для 800x480 дисплея
    parameter TOTAL_PIXELS = 800 * 480;
    
    wire delay_done = (delay_active == 0);
    assign led_1 = LCD_RESET;
    // Ініціалізація
    initial begin
        LCD_WR    = 1;
        LCD_RS    = 0;
        LCD_CS    = 1;
        LCD_RESET = 0;
        state     = 0;
        delay_cnt = 0;
        pixel_cnt = 0;
    end
    
initial begin
//                    LCD_WR_COMMAND(16'hF000); LCD_WR_DATA(16'h55);
//                    LCD_WR_COMMAND(16'hF001); LCD_WR_DATA(16'hAA);
//                    LCD_WR_COMMAND(16'hF002); LCD_WR_DATA(16'h52);
//                    LCD_WR_COMMAND(16'hF003); LCD_WR_DATA(16'h08);
//                    LCD_WR_COMMAND(16'hF004); LCD_WR_DATA(16'h01);
    init_rom[0] = {1'b0, 16'hF000};     init_rom[1] = {1'b1, 16'h0055}; 
    init_rom[2] = {1'b0, 16'hF001};     init_rom[3] = {1'b1, 16'h00AA}; 
    init_rom[4] = {1'b0, 16'hF002};     init_rom[5] = {1'b1, 16'h0052}; 
    init_rom[6] = {1'b0, 16'hF003};     init_rom[7] = {1'b1, 16'h0008}; 
    init_rom[8] = {1'b0, 16'hF004};     init_rom[9] = {1'b1, 16'h0001}; 
  //                    //# AVDD: manual); LCD_WR_DATA(
//                    LCD_WR_COMMAND(16'hB600); LCD_WR_DATA(16'h34);
//                    LCD_WR_COMMAND(16'hB601); LCD_WR_DATA(16'h34);
//                    LCD_WR_COMMAND(16'hB602); LCD_WR_DATA(16'h34);
    init_rom[10] = {1'b0, 16'hB600};     init_rom[11] = {1'b1, 16'h0034}; 
    init_rom[12] = {1'b0, 16'hB601};     init_rom[13] = {1'b1, 16'h0034}; 
    init_rom[14] = {1'b0, 16'hB602};      init_rom[15] = {1'b1, 16'h0034}; 
//                    LCD_WR_COMMAND(16'hB000); LCD_WR_DATA(16'h0D);//09
//                    LCD_WR_COMMAND(16'hB001); LCD_WR_DATA(16'h0D);
//                    LCD_WR_COMMAND(16'hB002); LCD_WR_DATA(16'h0D);
    init_rom[16] = {1'b0, 16'hB000};     init_rom[17] = {1'b1, 16'h000D}; 
    init_rom[18] = {1'b0, 16'hB001};     init_rom[19] = {1'b1, 16'h000D}; 
    init_rom[20] = {1'b0, 16'hB002};     init_rom[21] = {1'b1, 16'h000D};  
//                    //# AVEE: manual); LCD_WR_DATA( -6V
//                    LCD_WR_COMMAND(16'hB700); LCD_WR_DATA(16'h24);
//                    LCD_WR_COMMAND(16'hB701); LCD_WR_DATA(16'h24);
//                    LCD_WR_COMMAND(16'hB702); LCD_WR_DATA(16'h24);
    init_rom[22] = {1'b0, 16'hB700};     init_rom[23] = {1'b1, 16'h0024}; 
    init_rom[24] = {1'b0, 16'hB701};     init_rom[25] = {1'b1, 16'h0024}; 
    init_rom[26] = {1'b0, 16'hB702};     init_rom[27] = {1'b1, 16'h0024};
 //                    LCD_WR_COMMAND(16'hB100); LCD_WR_DATA(16'h0D);
//                    LCD_WR_COMMAND(16'hB101); LCD_WR_DATA(16'h0D);
//                    LCD_WR_COMMAND(16'hB102); LCD_WR_DATA(16'h0D);
    init_rom[28] = {1'b0, 16'hB100};     init_rom[29] = {1'b1, 16'h000D}; 
    init_rom[30] = {1'b0, 16'hB101};     init_rom[31] = {1'b1, 16'h000D}; 
    init_rom[32] = {1'b0, 16'hB102};     init_rom[33] = {1'b1, 16'h000D}; 
 //                    //#Power Control for
//                    //VCL
//                    LCD_WR_COMMAND(16'hB800); LCD_WR_DATA(16'h24);
//                    LCD_WR_COMMAND(16'hB801); LCD_WR_DATA(16'h24);
//                    LCD_WR_COMMAND(16'hB802); LCD_WR_DATA(16'h24);
            
//                    LCD_WR_COMMAND(16'hB200); LCD_WR_DATA(16'h00);   
    init_rom[34] = {1'b0, 16'hB800};     init_rom[35] = {1'b1, 16'h0024}; 
    init_rom[36] = {1'b0, 16'hB801};     init_rom[37] = {1'b1, 16'h0024}; 
    init_rom[38] = {1'b0, 16'hB802};     init_rom[39] = {1'b1, 16'h0024};     
    init_rom[40] = {1'b0, 16'hB200};     init_rom[41] = {1'b1, 16'h0000};  
//                    //# VGH: Clamp Enable); LCD_WR_DATA(
//                    LCD_WR_COMMAND(16'hB900); LCD_WR_DATA(16'h24);
//                    LCD_WR_COMMAND(16'hB901); LCD_WR_DATA(16'h24);
//                    LCD_WR_COMMAND(16'hB902); LCD_WR_DATA(16'h24);
            
//                    LCD_WR_COMMAND(16'hB300); LCD_WR_DATA(16'h05);
//                    LCD_WR_COMMAND(16'hB301); LCD_WR_DATA(16'h05);
//                    LCD_WR_COMMAND(16'hB302); LCD_WR_DATA(16'h05);    
    init_rom[42] = {1'b0, 16'hB900};     init_rom[43] = {1'b1, 16'h0024}; 
    init_rom[44] = {1'b0, 16'hB901};     init_rom[45] = {1'b1, 16'h0024}; 
    init_rom[46] = {1'b0, 16'hB902};     init_rom[47] = {1'b1, 16'h0024};
     
    init_rom[48] = {1'b0, 16'hB300};     init_rom[49] = {1'b1, 16'h0005}; 
    init_rom[50] = {1'b0, 16'hB301};     init_rom[51] = {1'b1, 16'h0005}; 
    init_rom[52] = {1'b0, 16'hB302};     init_rom[53] = {1'b1, 16'h0005};     
//                    //# VGL(LVGL):                                
//                    LCD_WR_COMMAND(16'hBA00); LCD_WR_DATA(16'h34);
//                    LCD_WR_COMMAND(16'hBA01); LCD_WR_DATA(16'h34);
//                    LCD_WR_COMMAND(16'hBA02); LCD_WR_DATA(16'h34);    
    init_rom[54] = {1'b0, 16'hBA00};     init_rom[55] = {1'b1, 16'h0034};
    init_rom[56] = {1'b0, 16'hBA01};     init_rom[57] = {1'b1, 16'h0034};
    init_rom[58] = {1'b0, 16'hBA02};     init_rom[59] = {1'b1, 16'h0034};    
//                    //# VGL_REG(VGLO)                             
//                    LCD_WR_COMMAND(16'hB500); LCD_WR_DATA(16'h0B);
//                    LCD_WR_COMMAND(16'hB501); LCD_WR_DATA(16'h0B);
//                    LCD_WR_COMMAND(16'hB502); LCD_WR_DATA(16'h0B);   
    init_rom[60] = {1'b0, 16'hB500};     init_rom[61] = {1'b1, 16'h000B};    
    init_rom[62] = {1'b0, 16'hB501};     init_rom[63] = {1'b1, 16'h000B};    
    init_rom[64] = {1'b0, 16'hB502};     init_rom[65] = {1'b1, 16'h000B};    
//                    //# VGMP/VGSP:                                
//                    LCD_WR_COMMAND(16'hBC00); LCD_WR_DATA(16'h00);
//                    LCD_WR_COMMAND(16'hBC01); LCD_WR_DATA(16'hA3);
//                    LCD_WR_COMMAND(16'hBC02); LCD_WR_DATA(16'h00);
    init_rom[66] = {1'b0, 16'hBC00};     init_rom[67] = {1'b1, 16'h0000};    
    init_rom[68] = {1'b0, 16'hBC01};     init_rom[69] = {1'b1, 16'h00A3};    
    init_rom[70] = {1'b0, 16'hBC02};     init_rom[71] = {1'b1, 16'h0000};    
 //                    //# VGMN/VGSN                                 
//                    LCD_WR_COMMAND(16'hBD00); LCD_WR_DATA(16'h00);
//                    LCD_WR_COMMAND(16'hBD01); LCD_WR_DATA(16'hA3);
//                    LCD_WR_COMMAND(16'hBD02); LCD_WR_DATA(16'h00);
    init_rom[72] = {1'b0, 16'hBD00};     init_rom[73] = {1'b1, 16'h0000}; 
    init_rom[74] = {1'b0, 16'hBD01};     init_rom[75] = {1'b1, 16'h00A3}; 
    init_rom[76] = {1'b0, 16'hBD02};     init_rom[77] = {1'b1, 16'h0000}; 
 //                    //# VCOM=-0.1                                     
//                    LCD_WR_COMMAND(16'hBE00); LCD_WR_DATA(16'h00);    
//                    LCD_WR_COMMAND(16'hBE01); LCD_WR_DATA(16'h63);//4f 
    init_rom[78] = {1'b0, 16'hBE00};     init_rom[79] = {1'b1, 16'h0000};
    init_rom[80] = {1'b0, 16'hBE01};     init_rom[81] = {1'b1, 16'h0063};  
//                        //  VCOMH+0x01;
//                    //#R+
//                    LCD_WR_COMMAND(16'hD100); LCD_WR_DATA(16'h00);
//                    LCD_WR_COMMAND(16'hD101); LCD_WR_DATA(16'h37);
//                    LCD_WR_COMMAND(16'hD102); LCD_WR_DATA(16'h00);
//                    LCD_WR_COMMAND(16'hD103); LCD_WR_DATA(16'h52);
//                    LCD_WR_COMMAND(16'hD104); LCD_WR_DATA(16'h00);
//                    LCD_WR_COMMAND(16'hD105); LCD_WR_DATA(16'h7B);
    init_rom[82] = {1'b0, 16'hD100};     init_rom[83] = {1'b1, 16'h0000}; 
    init_rom[84] = {1'b0, 16'hD101};     init_rom[85] = {1'b1, 16'h0037}; 
    init_rom[86] = {1'b0, 16'hD102};     init_rom[87] = {1'b1, 16'h0000};
    init_rom[88] = {1'b0, 16'hD103};     init_rom[89] = {1'b1, 16'h0052}; 
    init_rom[90] = {1'b0, 16'hD104};     init_rom[91] = {1'b1, 16'h0000}; 
    init_rom[92] = {1'b0, 16'hD105};     init_rom[93] = {1'b1, 16'h007B};     
   
//                    LCD_WR_COMMAND(16'hD106); LCD_WR_DATA(16'h00);
//                    LCD_WR_COMMAND(16'hD107); LCD_WR_DATA(16'h99);
//                    LCD_WR_COMMAND(16'hD108); LCD_WR_DATA(16'h00);
//                    LCD_WR_COMMAND(16'hD109); LCD_WR_DATA(16'hB1);
//                    LCD_WR_COMMAND(16'hD10A); LCD_WR_DATA(16'h00);
//                    LCD_WR_COMMAND(16'hD10B); LCD_WR_DATA(16'hD2);
    init_rom[94] = {1'b0, 16'hD106};     init_rom[95] = {1'b1, 16'h0000}; 
    init_rom[96] = {1'b0, 16'hD107};     init_rom[97] = {1'b1, 16'h0099}; 
    init_rom[98] = {1'b0, 16'hD108};     init_rom[99] = {1'b1, 16'h0000};
    init_rom[100] = {1'b0, 16'hD109};     init_rom[101] = {1'b1, 16'h00B1}; 
    init_rom[102] = {1'b0, 16'hD10A};     init_rom[102] = {1'b1, 16'h0000}; 
    init_rom[104] = {1'b0, 16'hD10B};     init_rom[105] = {1'b1, 16'h00D2};   
   
//                    LCD_WR_COMMAND(16'hD10C); LCD_WR_DATA(16'h00);
//                    LCD_WR_COMMAND(16'hD10D); LCD_WR_DATA(16'hF6);
//                    LCD_WR_COMMAND(16'hD10E); LCD_WR_DATA(16'h01);
//                    LCD_WR_COMMAND(16'hD10F); LCD_WR_DATA(16'h27);
//                    LCD_WR_COMMAND(16'hD110); LCD_WR_DATA(16'h01);
//                    LCD_WR_COMMAND(16'hD111); LCD_WR_DATA(16'h4E);
    init_rom[106] = {1'b0, 16'hD10C};     init_rom[107] = {1'b1, 16'h0000}; 
    init_rom[108] = {1'b0, 16'hD10D};     init_rom[109] = {1'b1, 16'h00F6}; 
    init_rom[110] = {1'b0, 16'hD10E};     init_rom[111] = {1'b1, 16'h0001};
    init_rom[112] = {1'b0, 16'hD10F};     init_rom[113] = {1'b1, 16'h0027}; 
    init_rom[114] = {1'b0, 16'hD110};     init_rom[115] = {1'b1, 16'h0001}; 
    init_rom[116] = {1'b0, 16'hD111};     init_rom[117] = {1'b1, 16'h004E};   
//                    LCD_WR_COMMAND(16'hD112); LCD_WR_DATA(16'h01);
//                    LCD_WR_COMMAND(16'hD113); LCD_WR_DATA(16'h8C);
//                    LCD_WR_COMMAND(16'hD114); LCD_WR_DATA(16'h01);
//                    LCD_WR_COMMAND(16'hD115); LCD_WR_DATA(16'hBE);
//                    LCD_WR_COMMAND(16'hD116); LCD_WR_DATA(16'h02);
//                    LCD_WR_COMMAND(16'hD117); LCD_WR_DATA(16'h0B);
    init_rom[118] = {1'b0, 16'hD112};     init_rom[119] = {1'b1, 16'h0001}; 
    init_rom[120] = {1'b0, 16'hD113};     init_rom[121] = {1'b1, 16'h008C}; 
    init_rom[122] = {1'b0, 16'hD114};     init_rom[123] = {1'b1, 16'h0001};
    init_rom[124] = {1'b0, 16'hD115};     init_rom[125] = {1'b1, 16'h00BE}; 
    init_rom[126] = {1'b0, 16'hD116};     init_rom[127] = {1'b1, 16'h0002}; 
    init_rom[128] = {1'b0, 16'hD117};     init_rom[129] = {1'b1, 16'h000B};   
//                    LCD_WR_COMMAND(16'hD118); LCD_WR_DATA(16'h02);
//                    LCD_WR_COMMAND(16'hD119); LCD_WR_DATA(16'h48);
//                    LCD_WR_COMMAND(16'hD11A); LCD_WR_DATA(16'h02);
//                    LCD_WR_COMMAND(16'hD11B); LCD_WR_DATA(16'h4A);
//                    LCD_WR_COMMAND(16'hD11C); LCD_WR_DATA(16'h02);
//                    LCD_WR_COMMAND(16'hD11D); LCD_WR_DATA(16'h7E);
    init_rom[130] = {1'b0, 16'hD118};     init_rom[131] = {1'b1, 16'h0002}; 
    init_rom[132] = {1'b0, 16'hD119};     init_rom[133] = {1'b1, 16'h0048}; 
    init_rom[134] = {1'b0, 16'hD11A};     init_rom[135] = {1'b1, 16'h0002};
    init_rom[136] = {1'b0, 16'hD11B};     init_rom[137] = {1'b1, 16'h004A}; 
    init_rom[138] = {1'b0, 16'hD11C};     init_rom[139] = {1'b1, 16'h0002}; 
    init_rom[140] = {1'b0, 16'hD11D};     init_rom[141] = {1'b1, 16'h007E};   

    init_rom[142] = {1'b0, 16'hD11E}; init_rom[143] = {1'b1, 16'h0002};
    init_rom[144] = {1'b0, 16'hD11F}; init_rom[145] = {1'b1, 16'h00BC};
    init_rom[146] = {1'b0, 16'hD120}; init_rom[147] = {1'b1, 16'h0002};
    init_rom[148] = {1'b0, 16'hD121}; init_rom[149] = {1'b1, 16'h00E1};
    init_rom[150] = {1'b0, 16'hD122}; init_rom[151] = {1'b1, 16'h0003};
    init_rom[152] = {1'b0, 16'hD123}; init_rom[153] = {1'b1, 16'h0010};
    init_rom[154] = {1'b0, 16'hD124}; init_rom[155] = {1'b1, 16'h0003};
    init_rom[156] = {1'b0, 16'hD125}; init_rom[157] = {1'b1, 16'h0031};
    init_rom[158] = {1'b0, 16'hD126}; init_rom[159] = {1'b1, 16'h0003};
    init_rom[160] = {1'b0, 16'hD127}; init_rom[161] = {1'b1, 16'h005A};
    init_rom[162] = {1'b0, 16'hD128}; init_rom[163] = {1'b1, 16'h0003};
    init_rom[164] = {1'b0, 16'hD129}; init_rom[165] = {1'b1, 16'h0073};
    init_rom[166] = {1'b0, 16'hD12A}; init_rom[167] = {1'b1, 16'h0003};
    init_rom[168] = {1'b0, 16'hD12B}; init_rom[169] = {1'b1, 16'h0094};
    init_rom[170] = {1'b0, 16'hD12C}; init_rom[171] = {1'b1, 16'h0003};
    init_rom[172] = {1'b0, 16'hD12D}; init_rom[173] = {1'b1, 16'h009F};
    init_rom[174] = {1'b0, 16'hD12E}; init_rom[175] = {1'b1, 16'h0003};
    init_rom[176] = {1'b0, 16'hD12F}; init_rom[177] = {1'b1, 16'h00B3};
    init_rom[178] = {1'b0, 16'hD130}; init_rom[179] = {1'b1, 16'h0003};
    init_rom[180] = {1'b0, 16'hD131}; init_rom[181] = {1'b1, 16'h00B9};
    init_rom[182] = {1'b0, 16'hD132}; init_rom[183] = {1'b1, 16'h0003};
    init_rom[184] = {1'b0, 16'hD133}; init_rom[185] = {1'b1, 16'h00C1};

    init_rom[186] = {1'b0, 16'hD200}; init_rom[187] = {1'b1, 16'h0000};
    init_rom[188] = {1'b0, 16'hD201}; init_rom[189] = {1'b1, 16'h0037};
    init_rom[190] = {1'b0, 16'hD202}; init_rom[191] = {1'b1, 16'h0000};
    init_rom[192] = {1'b0, 16'hD203}; init_rom[193] = {1'b1, 16'h0052};
    init_rom[194] = {1'b0, 16'hD204}; init_rom[195] = {1'b1, 16'h0000};
    init_rom[196] = {1'b0, 16'hD205}; init_rom[197] = {1'b1, 16'h007B};
    init_rom[198] = {1'b0, 16'hD206}; init_rom[199] = {1'b1, 16'h0000};
    init_rom[200] = {1'b0, 16'hD207}; init_rom[201] = {1'b1, 16'h0099};
    init_rom[202] = {1'b0, 16'hD208}; init_rom[203] = {1'b1, 16'h0000};
    init_rom[204] = {1'b0, 16'hD209}; init_rom[205] = {1'b1, 16'h00B1};
    init_rom[206] = {1'b0, 16'hD20A}; init_rom[207] = {1'b1, 16'h0000};
    init_rom[208] = {1'b0, 16'hD20B}; init_rom[209] = {1'b1, 16'h00D2};
    init_rom[210] = {1'b0, 16'hD20C}; init_rom[211] = {1'b1, 16'h0000};
    init_rom[212] = {1'b0, 16'hD20D}; init_rom[213] = {1'b1, 16'h00F6};
    init_rom[214] = {1'b0, 16'hD20E}; init_rom[215] = {1'b1, 16'h0001};
    init_rom[216] = {1'b0, 16'hD20F}; init_rom[217] = {1'b1, 16'h0027};
    init_rom[218] = {1'b0, 16'hD210}; init_rom[219] = {1'b1, 16'h0001};
    init_rom[220] = {1'b0, 16'hD211}; init_rom[221] = {1'b1, 16'h004E};
    init_rom[222] = {1'b0, 16'hD212}; init_rom[223] = {1'b1, 16'h0001};
    init_rom[224] = {1'b0, 16'hD213}; init_rom[225] = {1'b1, 16'h008C};
    init_rom[226] = {1'b0, 16'hD214}; init_rom[227] = {1'b1, 16'h0001};
    init_rom[228] = {1'b0, 16'hD215}; init_rom[229] = {1'b1, 16'h00BE};
    init_rom[230] = {1'b0, 16'hD216}; init_rom[231] = {1'b1, 16'h0002};
    init_rom[232] = {1'b0, 16'hD217}; init_rom[233] = {1'b1, 16'h000B};
    init_rom[234] = {1'b0, 16'hD218}; init_rom[235] = {1'b1, 16'h0002};
    init_rom[236] = {1'b0, 16'hD219}; init_rom[237] = {1'b1, 16'h0048};
    init_rom[238] = {1'b0, 16'hD21A}; init_rom[239] = {1'b1, 16'h0002};
    init_rom[240] = {1'b0, 16'hD21B}; init_rom[241] = {1'b1, 16'h004A};
    init_rom[242] = {1'b0, 16'hD21C}; init_rom[243] = {1'b1, 16'h0002};
    init_rom[244] = {1'b0, 16'hD21D}; init_rom[245] = {1'b1, 16'h007E};
    init_rom[246] = {1'b0, 16'hD21E}; init_rom[247] = {1'b1, 16'h0002};
    init_rom[248] = {1'b0, 16'hD21F}; init_rom[249] = {1'b1, 16'h00BC};
    init_rom[250] = {1'b0, 16'hD220}; init_rom[251] = {1'b1, 16'h0002};
    init_rom[252] = {1'b0, 16'hD221}; init_rom[253] = {1'b1, 16'h00E1};
    init_rom[254] = {1'b0, 16'hD222}; init_rom[255] = {1'b1, 16'h0003};
    init_rom[256] = {1'b0, 16'hD223}; init_rom[257] = {1'b1, 16'h0010};
    init_rom[258] = {1'b0, 16'hD224}; init_rom[259] = {1'b1, 16'h0003};
    init_rom[260] = {1'b0, 16'hD225}; init_rom[261] = {1'b1, 16'h0031};
    init_rom[262] = {1'b0, 16'hD226}; init_rom[263] = {1'b1, 16'h0003};
    init_rom[264] = {1'b0, 16'hD227}; init_rom[265] = {1'b1, 16'h005A};
    init_rom[266] = {1'b0, 16'hD228}; init_rom[267] = {1'b1, 16'h0003};
    init_rom[268] = {1'b0, 16'hD229}; init_rom[269] = {1'b1, 16'h0073};
    init_rom[270] = {1'b0, 16'hD22A}; init_rom[271] = {1'b1, 16'h0003};
    init_rom[272] = {1'b0, 16'hD22B}; init_rom[273] = {1'b1, 16'h0094};
    init_rom[274] = {1'b0, 16'hD22C}; init_rom[275] = {1'b1, 16'h0003};
    init_rom[276] = {1'b0, 16'hD22D}; init_rom[277] = {1'b1, 16'h009F};
    init_rom[278] = {1'b0, 16'hD22E}; init_rom[279] = {1'b1, 16'h0003};
    init_rom[280] = {1'b0, 16'hD22F}; init_rom[281] = {1'b1, 16'h00B3};
    init_rom[282] = {1'b0, 16'hD230}; init_rom[283] = {1'b1, 16'h0003};
    init_rom[284] = {1'b0, 16'hD231}; init_rom[285] = {1'b1, 16'h00B9};
    init_rom[286] = {1'b0, 16'hD232}; init_rom[287] = {1'b1, 16'h0003};
    init_rom[288] = {1'b0, 16'hD233}; init_rom[289] = {1'b1, 16'h00C1};

    // #B+
    init_rom[290] = {1'b0, 16'hD300}; init_rom[291] = {1'b1, 16'h0000};
    init_rom[292] = {1'b0, 16'hD301}; init_rom[293] = {1'b1, 16'h0037};
    init_rom[294] = {1'b0, 16'hD302}; init_rom[295] = {1'b1, 16'h0000};
    init_rom[296] = {1'b0, 16'hD303}; init_rom[297] = {1'b1, 16'h0052};
    init_rom[298] = {1'b0, 16'hD304}; init_rom[299] = {1'b1, 16'h0000};
    init_rom[300] = {1'b0, 16'hD305}; init_rom[301] = {1'b1, 16'h007B};
    init_rom[302] = {1'b0, 16'hD306}; init_rom[303] = {1'b1, 16'h0000};
    init_rom[304] = {1'b0, 16'hD307}; init_rom[305] = {1'b1, 16'h0099};
    init_rom[306] = {1'b0, 16'hD308}; init_rom[307] = {1'b1, 16'h0000};
    init_rom[308] = {1'b0, 16'hD309}; init_rom[309] = {1'b1, 16'h00B1};
    init_rom[310] = {1'b0, 16'hD30A}; init_rom[311] = {1'b1, 16'h0000};
    init_rom[312] = {1'b0, 16'hD30B}; init_rom[313] = {1'b1, 16'h00D2};
    init_rom[314] = {1'b0, 16'hD30C}; init_rom[315] = {1'b1, 16'h0000};
    init_rom[316] = {1'b0, 16'hD30D}; init_rom[317] = {1'b1, 16'h00F6};
    init_rom[318] = {1'b0, 16'hD30E}; init_rom[319] = {1'b1, 16'h0001};
    init_rom[320] = {1'b0, 16'hD30F}; init_rom[321] = {1'b1, 16'h0027};
    init_rom[322] = {1'b0, 16'hD310}; init_rom[323] = {1'b1, 16'h0001};
    init_rom[324] = {1'b0, 16'hD311}; init_rom[325] = {1'b1, 16'h004E};
    init_rom[326] = {1'b0, 16'hD312}; init_rom[327] = {1'b1, 16'h0001};
    init_rom[328] = {1'b0, 16'hD313}; init_rom[329] = {1'b1, 16'h008C};
    init_rom[330] = {1'b0, 16'hD314}; init_rom[331] = {1'b1, 16'h0001};
    init_rom[332] = {1'b0, 16'hD315}; init_rom[333] = {1'b1, 16'h00BE};
    init_rom[334] = {1'b0, 16'hD316}; init_rom[335] = {1'b1, 16'h0002};
    init_rom[336] = {1'b0, 16'hD317}; init_rom[337] = {1'b1, 16'h000B};
    init_rom[338] = {1'b0, 16'hD318}; init_rom[339] = {1'b1, 16'h0002};
    init_rom[340] = {1'b0, 16'hD319}; init_rom[341] = {1'b1, 16'h0048};
    init_rom[342] = {1'b0, 16'hD31A}; init_rom[343] = {1'b1, 16'h0002};
    init_rom[344] = {1'b0, 16'hD31B}; init_rom[345] = {1'b1, 16'h004A};
    init_rom[346] = {1'b0, 16'hD31C}; init_rom[347] = {1'b1, 16'h0002};
    init_rom[348] = {1'b0, 16'hD31D}; init_rom[349] = {1'b1, 16'h007E};
    init_rom[350] = {1'b0, 16'hD31E}; init_rom[351] = {1'b1, 16'h0002};
    init_rom[352] = {1'b0, 16'hD31F}; init_rom[353] = {1'b1, 16'h00BC};
    init_rom[354] = {1'b0, 16'hD320}; init_rom[355] = {1'b1, 16'h0002};
    init_rom[356] = {1'b0, 16'hD321}; init_rom[357] = {1'b1, 16'h00E1};
    init_rom[358] = {1'b0, 16'hD322}; init_rom[359] = {1'b1, 16'h0003};
    init_rom[360] = {1'b0, 16'hD323}; init_rom[361] = {1'b1, 16'h0010};
    init_rom[362] = {1'b0, 16'hD324}; init_rom[363] = {1'b1, 16'h0003};
    init_rom[364] = {1'b0, 16'hD325}; init_rom[365] = {1'b1, 16'h0031};
    init_rom[366] = {1'b0, 16'hD326}; init_rom[367] = {1'b1, 16'h0003};
    init_rom[368] = {1'b0, 16'hD327}; init_rom[369] = {1'b1, 16'h005A};
    init_rom[370] = {1'b0, 16'hD328}; init_rom[371] = {1'b1, 16'h0003};
    init_rom[372] = {1'b0, 16'hD329}; init_rom[373] = {1'b1, 16'h0073};
    init_rom[374] = {1'b0, 16'hD32A}; init_rom[375] = {1'b1, 16'h0003};
    init_rom[376] = {1'b0, 16'hD32B}; init_rom[377] = {1'b1, 16'h0094};
    init_rom[378] = {1'b0, 16'hD32C}; init_rom[379] = {1'b1, 16'h0003};
    init_rom[380] = {1'b0, 16'hD32D}; init_rom[381] = {1'b1, 16'h009F};
    init_rom[382] = {1'b0, 16'hD32E}; init_rom[383] = {1'b1, 16'h0003};
    init_rom[384] = {1'b0, 16'hD32F}; init_rom[385] = {1'b1, 16'h00B3};
    init_rom[386] = {1'b0, 16'hD330}; init_rom[387] = {1'b1, 16'h0003};
    init_rom[388] = {1'b0, 16'hD331}; init_rom[389] = {1'b1, 16'h00B9};
    init_rom[390] = {1'b0, 16'hD332}; init_rom[391] = {1'b1, 16'h0003};
    init_rom[392] = {1'b0, 16'hD333}; init_rom[393] = {1'b1, 16'h00C1};
    init_rom[394] = {1'b0, 16'hD400}; init_rom[395] = {1'b1, 16'h0000};
    init_rom[396] = {1'b0, 16'hD401}; init_rom[397] = {1'b1, 16'h0037};
    init_rom[398] = {1'b0, 16'hD402}; init_rom[399] = {1'b1, 16'h0000};
    init_rom[400] = {1'b0, 16'hD403}; init_rom[401] = {1'b1, 16'h0052};
    init_rom[402] = {1'b0, 16'hD404}; init_rom[403] = {1'b1, 16'h0000};
    init_rom[404] = {1'b0, 16'hD405}; init_rom[405] = {1'b1, 16'h007B};
    init_rom[406] = {1'b0, 16'hD406}; init_rom[407] = {1'b1, 16'h0000};
    init_rom[408] = {1'b0, 16'hD407}; init_rom[409] = {1'b1, 16'h0099};
    init_rom[410] = {1'b0, 16'hD408}; init_rom[411] = {1'b1, 16'h0000};
    init_rom[412] = {1'b0, 16'hD409}; init_rom[413] = {1'b1, 16'h00B1};
    init_rom[414] = {1'b0, 16'hD40A}; init_rom[415] = {1'b1, 16'h0000};
    init_rom[416] = {1'b0, 16'hD40B}; init_rom[417] = {1'b1, 16'h00D2};
    init_rom[418] = {1'b0, 16'hD40C}; init_rom[419] = {1'b1, 16'h0000};
    init_rom[420] = {1'b0, 16'hD40D}; init_rom[421] = {1'b1, 16'h00F6};
    init_rom[422] = {1'b0, 16'hD40E}; init_rom[423] = {1'b1, 16'h0001};
    init_rom[424] = {1'b0, 16'hD40F}; init_rom[425] = {1'b1, 16'h0027};
    init_rom[426] = {1'b0, 16'hD410}; init_rom[427] = {1'b1, 16'h0001};
    init_rom[428] = {1'b0, 16'hD411}; init_rom[429] = {1'b1, 16'h004E};
    init_rom[430] = {1'b0, 16'hD412}; init_rom[431] = {1'b1, 16'h0001};
    init_rom[432] = {1'b0, 16'hD413}; init_rom[433] = {1'b1, 16'h008C};
    init_rom[434] = {1'b0, 16'hD414}; init_rom[435] = {1'b1, 16'h0001};
    init_rom[436] = {1'b0, 16'hD415}; init_rom[437] = {1'b1, 16'h00BE};
    init_rom[438] = {1'b0, 16'hD416}; init_rom[439] = {1'b1, 16'h0002};
    init_rom[440] = {1'b0, 16'hD417}; init_rom[441] = {1'b1, 16'h000B};
    init_rom[442] = {1'b0, 16'hD418}; init_rom[443] = {1'b1, 16'h0002};
    init_rom[444] = {1'b0, 16'hD419}; init_rom[445] = {1'b1, 16'h0048};
    init_rom[446] = {1'b0, 16'hD41A}; init_rom[447] = {1'b1, 16'h0002};
    init_rom[448] = {1'b0, 16'hD41B}; init_rom[449] = {1'b1, 16'h004A};
    init_rom[450] = {1'b0, 16'hD41C}; init_rom[451] = {1'b1, 16'h0002};
    init_rom[452] = {1'b0, 16'hD41D}; init_rom[453] = {1'b1, 16'h007E};
    init_rom[454] = {1'b0, 16'hD41E}; init_rom[455] = {1'b1, 16'h0002};
    init_rom[456] = {1'b0, 16'hD41F}; init_rom[457] = {1'b1, 16'h00BC};
    init_rom[458] = {1'b0, 16'hD420}; init_rom[459] = {1'b1, 16'h0002};
    init_rom[460] = {1'b0, 16'hD421}; init_rom[461] = {1'b1, 16'h00E1};
    init_rom[462] = {1'b0, 16'hD422}; init_rom[463] = {1'b1, 16'h0003};
    init_rom[464] = {1'b0, 16'hD423}; init_rom[465] = {1'b1, 16'h0010};
    init_rom[466] = {1'b0, 16'hD424}; init_rom[467] = {1'b1, 16'h0003};
    init_rom[468] = {1'b0, 16'hD425}; init_rom[469] = {1'b1, 16'h0031};
    init_rom[470] = {1'b0, 16'hD426}; init_rom[471] = {1'b1, 16'h0003};
    init_rom[472] = {1'b0, 16'hD427}; init_rom[473] = {1'b1, 16'h005A};
    init_rom[474] = {1'b0, 16'hD428}; init_rom[475] = {1'b1, 16'h0003};
    init_rom[476] = {1'b0, 16'hD429}; init_rom[477] = {1'b1, 16'h0073};
    init_rom[478] = {1'b0, 16'hD42A}; init_rom[479] = {1'b1, 16'h0003};
    init_rom[480] = {1'b0, 16'hD42B}; init_rom[481] = {1'b1, 16'h0094};
    init_rom[482] = {1'b0, 16'hD42C}; init_rom[483] = {1'b1, 16'h0003};
    init_rom[484] = {1'b0, 16'hD42D}; init_rom[485] = {1'b1, 16'h009F};
    init_rom[486] = {1'b0, 16'hD42E}; init_rom[487] = {1'b1, 16'h0003};
    init_rom[488] = {1'b0, 16'hD42F}; init_rom[489] = {1'b1, 16'h00B3};
    init_rom[490] = {1'b0, 16'hD430}; init_rom[491] = {1'b1, 16'h0003};
    init_rom[492] = {1'b0, 16'hD431}; init_rom[493] = {1'b1, 16'h00B9};
    init_rom[494] = {1'b0, 16'hD432}; init_rom[495] = {1'b1, 16'h0003};
    init_rom[496] = {1'b0, 16'hD433}; init_rom[497] = {1'b1, 16'h00C1};
    init_rom[498] = {1'b0, 16'hD434}; init_rom[499] = {1'b1, 16'h0003};
    init_rom[500] = {1'b0, 16'hD435}; init_rom[501] = {1'b1, 16'h00D2};
    init_rom[502] = {1'b0, 16'hD436}; init_rom[503] = {1'b1, 16'h0003};
    init_rom[504] = {1'b0, 16'hD437}; init_rom[505] = {1'b1, 16'h00E3};
    init_rom[506] = {1'b0, 16'hD438}; init_rom[507] = {1'b1, 16'h0003};
    init_rom[508] = {1'b0, 16'hD439}; init_rom[509] = {1'b1, 16'h00F5};
    init_rom[510] = {1'b0, 16'hD43A}; init_rom[511] = {1'b1, 16'h0003};
    init_rom[512] = {1'b0, 16'hD43B}; init_rom[513] = {1'b1, 16'h00FF};
    init_rom[514] = {1'b0, 16'hD43C}; init_rom[515] = {1'b1, 16'h0000};
    init_rom[516] = {1'b0, 16'hD43D}; init_rom[517] = {1'b1, 16'h0017};
    init_rom[518] = {1'b0, 16'hD43E}; init_rom[519] = {1'b1, 16'h0000};
    init_rom[520] = {1'b0, 16'hD43F}; init_rom[521] = {1'b1, 16'h0037};
    init_rom[522] = {1'b0, 16'hD440}; init_rom[523] = {1'b1, 16'h0000};
    init_rom[524] = {1'b0, 16'hD441}; init_rom[525] = {1'b1, 16'h0052};
    init_rom[526] = {1'b0, 16'hD442}; init_rom[527] = {1'b1, 16'h0000};
    init_rom[528] = {1'b0, 16'hD443}; init_rom[529] = {1'b1, 16'h007B};
    init_rom[530] = {1'b0, 16'hD444}; init_rom[531] = {1'b1, 16'h0000};
    init_rom[532] = {1'b0, 16'hD445}; init_rom[533] = {1'b1, 16'h0099};
    init_rom[534] = {1'b0, 16'hD446}; init_rom[535] = {1'b1, 16'h0000};
    init_rom[536] = {1'b0, 16'hD447}; init_rom[537] = {1'b1, 16'h00B1};
    init_rom[538] = {1'b0, 16'hD448}; init_rom[539] = {1'b1, 16'h0000};
    init_rom[540] = {1'b0, 16'hD449}; init_rom[541] = {1'b1, 16'h00D2};
    init_rom[542] = {1'b0, 16'hD44A}; init_rom[543] = {1'b1, 16'h0000};
    init_rom[544] = {1'b0, 16'hD44B}; init_rom[545] = {1'b1, 16'h00F6};
    init_rom[546] = {1'b0, 16'hD44C}; init_rom[547] = {1'b1, 16'h0001};
    init_rom[548] = {1'b0, 16'hD44D}; init_rom[549] = {1'b1, 16'h0027};
    init_rom[550] = {1'b0, 16'hD44E}; init_rom[551] = {1'b1, 16'h0001};
    init_rom[552] = {1'b0, 16'hD44F}; init_rom[553] = {1'b1, 16'h004E};
    init_rom[554] = {1'b0, 16'hD450}; init_rom[555] = {1'b1, 16'h0001};
    init_rom[556] = {1'b0, 16'hD451}; init_rom[557] = {1'b1, 16'h008C};
    init_rom[558] = {1'b0, 16'hD452}; init_rom[559] = {1'b1, 16'h0001};
    init_rom[560] = {1'b0, 16'hD453}; init_rom[561] = {1'b1, 16'h00BE};
    init_rom[562] = {1'b0, 16'hD454}; init_rom[563] = {1'b1, 16'h0002};
    init_rom[564] = {1'b0, 16'hD455}; init_rom[565] = {1'b1, 16'h000B};
    init_rom[566] = {1'b0, 16'hD456}; init_rom[567] = {1'b1, 16'h0002};
    init_rom[568] = {1'b0, 16'hD457}; init_rom[569] = {1'b1, 16'h0048};
    init_rom[570] = {1'b0, 16'hD458}; init_rom[571] = {1'b1, 16'h0002};
    init_rom[572] = {1'b0, 16'hD459}; init_rom[573] = {1'b1, 16'h004A};
    init_rom[574] = {1'b0, 16'hD45A}; init_rom[575] = {1'b1, 16'h0002};
    init_rom[576] = {1'b0, 16'hD45B}; init_rom[577] = {1'b1, 16'h007E};
    init_rom[578] = {1'b0, 16'hD45C}; init_rom[579] = {1'b1, 16'h0002};
    init_rom[580] = {1'b0, 16'hD45D}; init_rom[581] = {1'b1, 16'h00BC};
    init_rom[582] = {1'b0, 16'hD45E}; init_rom[583] = {1'b1, 16'h0002};
    init_rom[584] = {1'b0, 16'hD45F}; init_rom[585] = {1'b1, 16'h00E1};
    init_rom[586] = {1'b0, 16'hD460}; init_rom[587] = {1'b1, 16'h0003};
    init_rom[588] = {1'b0, 16'hD461}; init_rom[589] = {1'b1, 16'h0010};
    init_rom[590] = {1'b0, 16'hD462}; init_rom[591] = {1'b1, 16'h0003};
    init_rom[592] = {1'b0, 16'hD463}; init_rom[593] = {1'b1, 16'h0031};
    init_rom[594] = {1'b0, 16'hD464}; init_rom[595] = {1'b1, 16'h0003};
    init_rom[596] = {1'b0, 16'hD465}; init_rom[597] = {1'b1, 16'h005A};
    init_rom[598] = {1'b0, 16'hD466}; init_rom[599] = {1'b1, 16'h0003};
    init_rom[600] = {1'b0, 16'hD467}; init_rom[601] = {1'b1, 16'h0073};
    init_rom[602] = {1'b0, 16'hD468}; init_rom[603] = {1'b1, 16'h0003};
    init_rom[604] = {1'b0, 16'hD469}; init_rom[605] = {1'b1, 16'h0094};
    init_rom[606] = {1'b0, 16'hD46A}; init_rom[607] = {1'b1, 16'h0003};
    init_rom[608] = {1'b0, 16'hD46B}; init_rom[609] = {1'b1, 16'h009F};
    init_rom[610] = {1'b0, 16'hD46C}; init_rom[611] = {1'b1, 16'h0003};
    init_rom[612] = {1'b0, 16'hD46D}; init_rom[613] = {1'b1, 16'h00B3};
    init_rom[614] = {1'b0, 16'hD46E}; init_rom[615] = {1'b1, 16'h0003};
    init_rom[616] = {1'b0, 16'hD46F}; init_rom[617] = {1'b1, 16'h00B9};
    init_rom[618] = {1'b0, 16'hD470}; init_rom[619] = {1'b1, 16'h0003};
    init_rom[620] = {1'b0, 16'hD471}; init_rom[621] = {1'b1, 16'h00C1};
    init_rom[622] = {1'b0, 16'hD472}; init_rom[623] = {1'b1, 16'h0003};
    init_rom[624] = {1'b0, 16'hD473}; init_rom[625] = {1'b1, 16'h00D2};
    init_rom[626] = {1'b0, 16'hD474}; init_rom[627] = {1'b1, 16'h0003};
    init_rom[628] = {1'b0, 16'hD475}; init_rom[629] = {1'b1, 16'h00E3};
    init_rom[630] = {1'b0, 16'hD476}; init_rom[631] = {1'b1, 16'h0003};
    init_rom[632] = {1'b0, 16'hD477}; init_rom[633] = {1'b1, 16'h00F5};
    init_rom[634] = {1'b0, 16'hD478}; init_rom[635] = {1'b1, 16'h0003};
    init_rom[636] = {1'b0, 16'hD479}; init_rom[637] = {1'b1, 16'h00FF};
end

reg [2:0] wr_state;
reg [15:0] wr_data;
reg wr_is_cmd; // 1 - команда, 0 - дані
reg wr_start;
reg wr_busy;

task LCD_WR_COMMAND;
    input [15:0] cmd;
    begin
        wr_data <= cmd;
        wr_is_cmd <= 1; // це команда
        wr_start <= 1;
    end
endtask

task LCD_WR_DATA;
    input [15:0] data;
    begin
        wr_data <= data;
        wr_is_cmd <= 0; // це дані
        wr_start <= 1;
    end
endtask

    task start_delay_ms;
        input [15:0] ms;
        begin
            delay_counter <= ms * 50000;  // 1 мс = 50 000 тактів при 50 МГц
            delay_active  <= 1;
        end
    endtask
    


always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        wr_state <= 0;
        LCD_WR <= 1;
        LCD_CS <= 1;
        LCD_RS <= 1;
        wr_busy <= 0;
    end else begin
        case (wr_state)
            0: begin
                if (wr_start) begin
                    wr_busy <= 1;
                    LCD_DATA <= wr_data;
                    LCD_RS <= (wr_is_cmd) ? 0 : 1;
                    LCD_CS <= 0;
                    LCD_WR <= 0;
                    wr_state <= 1;
                end else begin
                    wr_busy <= 0;
                    LCD_WR <= 1;
                    LCD_CS <= 1;
                end
            end

            1: begin
                // Тримаємо WR низьким 1 такт
                LCD_WR <= 1;
                LCD_CS <= 1;
                wr_state <= 2;
            end

            2: begin
                wr_state <= 0;
            end
        endcase
    end
end

    // Основна логіка
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state     <= 0;
            delay_cnt <= 0;
            pixel_cnt <= 0;
            LCD_RESET <= 0;
            
            delay_counter <= 0;
            delay_active  <= 0;
        end else begin
        if (delay_active) begin
            if (delay_counter > 0)
                delay_counter <= delay_counter - 1;
            else
                delay_active <= 0;
        end
            case (state)
                0: begin
                    // Скидання дисплея
                    start_delay_ms(120); // старт затримки 
                    state     <= 1;
                end
                1: begin
                    if (delay_done) begin
                        LCD_RESET <= 1; //відпускаємо ресет
                        state     <= 2;
                    end
                end
                    2: begin
        if (!wr_busy) begin
            if (init_rom_data[17] == 1'b0)
                LCD_WR_COMMAND(init_rom_data[15:0]);
            else
                LCD_WR_DATA(init_rom_data[15:0]);
            
            if (init_rom_addr ==638) begin
                // Кінець ініціалізації
                start_delay_ms(120);
                state <= 3;
            end else begin
                init_rom_addr <= init_rom_addr + 1;
            end
        end
    end
//                    LCD_WR_COMMAND(16'hD11E); LCD_WR_DATA(16'h02);
//                    LCD_WR_COMMAND(16'hD11F); LCD_WR_DATA(16'hBC);
//                    LCD_WR_COMMAND(16'hD120); LCD_WR_DATA(16'h02);
//                    LCD_WR_COMMAND(16'hD121); LCD_WR_DATA(16'hE1);
//                    LCD_WR_COMMAND(16'hD122); LCD_WR_DATA(16'h03);
//                    LCD_WR_COMMAND(16'hD123); LCD_WR_DATA(16'h10);
//                    LCD_WR_COMMAND(16'hD124); LCD_WR_DATA(16'h03);
//                    LCD_WR_COMMAND(16'hD125); LCD_WR_DATA(16'h31);
//                    LCD_WR_COMMAND(16'hD126); LCD_WR_DATA(16'h03);
//                    LCD_WR_COMMAND(16'hD127); LCD_WR_DATA(16'h5A);
//                    LCD_WR_COMMAND(16'hD128); LCD_WR_DATA(16'h03);
//                    LCD_WR_COMMAND(16'hD129); LCD_WR_DATA(16'h73);
//                    LCD_WR_COMMAND(16'hD12A); LCD_WR_DATA(16'h03);
//                    LCD_WR_COMMAND(16'hD12B); LCD_WR_DATA(16'h94);
//                    LCD_WR_COMMAND(16'hD12C); LCD_WR_DATA(16'h03);
//                    LCD_WR_COMMAND(16'hD12D); LCD_WR_DATA(16'h9F);
//                    LCD_WR_COMMAND(16'hD12E); LCD_WR_DATA(16'h03);
//                    LCD_WR_COMMAND(16'hD12F); LCD_WR_DATA(16'hB3);
//                    LCD_WR_COMMAND(16'hD130); LCD_WR_DATA(16'h03);
//                    LCD_WR_COMMAND(16'hD131); LCD_WR_DATA(16'hB9);
//                    LCD_WR_COMMAND(16'hD132); LCD_WR_DATA(16'h03);
//                    LCD_WR_COMMAND(16'hD133); LCD_WR_DATA(16'hC1);
//                    //#G+
//                    LCD_WR_COMMAND(16'hD200); LCD_WR_DATA(16'h00);
//                    LCD_WR_COMMAND(16'hD201); LCD_WR_DATA(16'h37);
//                    LCD_WR_COMMAND(16'hD202); LCD_WR_DATA(16'h00);
//                    LCD_WR_COMMAND(16'hD203); LCD_WR_DATA(16'h52);
//                    LCD_WR_COMMAND(16'hD204); LCD_WR_DATA(16'h00);
//                    LCD_WR_COMMAND(16'hD205); LCD_WR_DATA(16'h7B);
//                    LCD_WR_COMMAND(16'hD206); LCD_WR_DATA(16'h00);
//                    LCD_WR_COMMAND(16'hD207); LCD_WR_DATA(16'h99);
//                    LCD_WR_COMMAND(16'hD208); LCD_WR_DATA(16'h00);
//                    LCD_WR_COMMAND(16'hD209); LCD_WR_DATA(16'hB1);
//                    LCD_WR_COMMAND(16'hD20A); LCD_WR_DATA(16'h00);
//                    LCD_WR_COMMAND(16'hD20B); LCD_WR_DATA(16'hD2);
//                    LCD_WR_COMMAND(16'hD20C); LCD_WR_DATA(16'h00);
//                    LCD_WR_COMMAND(16'hD20D); LCD_WR_DATA(16'hF6);
//                    LCD_WR_COMMAND(16'hD20E); LCD_WR_DATA(16'h01);
//                    LCD_WR_COMMAND(16'hD20F); LCD_WR_DATA(16'h27);
//                    LCD_WR_COMMAND(16'hD210); LCD_WR_DATA(16'h01);
//                    LCD_WR_COMMAND(16'hD211); LCD_WR_DATA(16'h4E);
//                    LCD_WR_COMMAND(16'hD212); LCD_WR_DATA(16'h01);
//                    LCD_WR_COMMAND(16'hD213); LCD_WR_DATA(16'h8C);
//                    LCD_WR_COMMAND(16'hD214); LCD_WR_DATA(16'h01);
//                    LCD_WR_COMMAND(16'hD215); LCD_WR_DATA(16'hBE);
//                    LCD_WR_COMMAND(16'hD216); LCD_WR_DATA(16'h02);
//                    LCD_WR_COMMAND(16'hD217); LCD_WR_DATA(16'h0B);
//                    LCD_WR_COMMAND(16'hD218); LCD_WR_DATA(16'h02);
//                    LCD_WR_COMMAND(16'hD219); LCD_WR_DATA(16'h48);
//                    LCD_WR_COMMAND(16'hD21A); LCD_WR_DATA(16'h02);
//                    LCD_WR_COMMAND(16'hD21B); LCD_WR_DATA(16'h4A);
//                    LCD_WR_COMMAND(16'hD21C); LCD_WR_DATA(16'h02);
//                    LCD_WR_COMMAND(16'hD21D); LCD_WR_DATA(16'h7E);
//                    LCD_WR_COMMAND(16'hD21E); LCD_WR_DATA(16'h02);
//                    LCD_WR_COMMAND(16'hD21F); LCD_WR_DATA(16'hBC);
//                    LCD_WR_COMMAND(16'hD220); LCD_WR_DATA(16'h02);
//                    LCD_WR_COMMAND(16'hD221); LCD_WR_DATA(16'hE1);
//                    LCD_WR_COMMAND(16'hD222); LCD_WR_DATA(16'h03);
//                    LCD_WR_COMMAND(16'hD223); LCD_WR_DATA(16'h10);
//                    LCD_WR_COMMAND(16'hD224); LCD_WR_DATA(16'h03);
//                    LCD_WR_COMMAND(16'hD225); LCD_WR_DATA(16'h31);
//                    LCD_WR_COMMAND(16'hD226); LCD_WR_DATA(16'h03);
//                    LCD_WR_COMMAND(16'hD227); LCD_WR_DATA(16'h5A);
//                    LCD_WR_COMMAND(16'hD228); LCD_WR_DATA(16'h03);
//                    LCD_WR_COMMAND(16'hD229); LCD_WR_DATA(16'h73);
//                    LCD_WR_COMMAND(16'hD22A); LCD_WR_DATA(16'h03);
//                    LCD_WR_COMMAND(16'hD22B); LCD_WR_DATA(16'h94);
//                    LCD_WR_COMMAND(16'hD22C); LCD_WR_DATA(16'h03);
//                    LCD_WR_COMMAND(16'hD22D); LCD_WR_DATA(16'h9F);
//                    LCD_WR_COMMAND(16'hD22E); LCD_WR_DATA(16'h03);
//                    LCD_WR_COMMAND(16'hD22F); LCD_WR_DATA(16'hB3);
//                    LCD_WR_COMMAND(16'hD230); LCD_WR_DATA(16'h03);
//                    LCD_WR_COMMAND(16'hD231); LCD_WR_DATA(16'hB9);
//                    LCD_WR_COMMAND(16'hD232); LCD_WR_DATA(16'h03);
//                    LCD_WR_COMMAND(16'hD233); LCD_WR_DATA(16'hC1);
//                    //#B+
//                    LCD_WR_COMMAND(16'hD300); LCD_WR_DATA(16'h00);
//                    LCD_WR_COMMAND(16'hD301); LCD_WR_DATA(16'h37);
//                    LCD_WR_COMMAND(16'hD302); LCD_WR_DATA(16'h00);
//                    LCD_WR_COMMAND(16'hD303); LCD_WR_DATA(16'h52);
//                    LCD_WR_COMMAND(16'hD304); LCD_WR_DATA(16'h00);
//                    LCD_WR_COMMAND(16'hD305); LCD_WR_DATA(16'h7B);
//                    LCD_WR_COMMAND(16'hD306); LCD_WR_DATA(16'h00);
//                    LCD_WR_COMMAND(16'hD307); LCD_WR_DATA(16'h99);
//                    LCD_WR_COMMAND(16'hD308); LCD_WR_DATA(16'h00);
//                    LCD_WR_COMMAND(16'hD309); LCD_WR_DATA(16'hB1);
//                    LCD_WR_COMMAND(16'hD30A); LCD_WR_DATA(16'h00);
//                    LCD_WR_COMMAND(16'hD30B); LCD_WR_DATA(16'hD2);
//                    LCD_WR_COMMAND(16'hD30C); LCD_WR_DATA(16'h00);
//                    LCD_WR_COMMAND(16'hD30D); LCD_WR_DATA(16'hF6);
//                    LCD_WR_COMMAND(16'hD30E); LCD_WR_DATA(16'h01);
//                    LCD_WR_COMMAND(16'hD30F); LCD_WR_DATA(16'h27);
//                    LCD_WR_COMMAND(16'hD310); LCD_WR_DATA(16'h01);
//                    LCD_WR_COMMAND(16'hD311); LCD_WR_DATA(16'h4E);
//                    LCD_WR_COMMAND(16'hD312); LCD_WR_DATA(16'h01);
//                    LCD_WR_COMMAND(16'hD313); LCD_WR_DATA(16'h8C);
//                    LCD_WR_COMMAND(16'hD314); LCD_WR_DATA(16'h01);
//                    LCD_WR_COMMAND(16'hD315); LCD_WR_DATA(16'hBE);
//                    LCD_WR_COMMAND(16'hD316); LCD_WR_DATA(16'h02);
//                    LCD_WR_COMMAND(16'hD317); LCD_WR_DATA(16'h0B);
//                    LCD_WR_COMMAND(16'hD318); LCD_WR_DATA(16'h02);
//                    LCD_WR_COMMAND(16'hD319); LCD_WR_DATA(16'h48);
//                    LCD_WR_COMMAND(16'hD31A); LCD_WR_DATA(16'h02);
//                    LCD_WR_COMMAND(16'hD31B); LCD_WR_DATA(16'h4A);
//                    LCD_WR_COMMAND(16'hD31C); LCD_WR_DATA(16'h02);
//                    LCD_WR_COMMAND(16'hD31D); LCD_WR_DATA(16'h7E);
//                    LCD_WR_COMMAND(16'hD31E); LCD_WR_DATA(16'h02);
//                    LCD_WR_COMMAND(16'hD31F); LCD_WR_DATA(16'hBC);
//                    LCD_WR_COMMAND(16'hD320); LCD_WR_DATA(16'h02);
//                    LCD_WR_COMMAND(16'hD321); LCD_WR_DATA(16'hE1);
//                    LCD_WR_COMMAND(16'hD322); LCD_WR_DATA(16'h03);
//                    LCD_WR_COMMAND(16'hD323); LCD_WR_DATA(16'h10);
//                    LCD_WR_COMMAND(16'hD324); LCD_WR_DATA(16'h03);
//                    LCD_WR_COMMAND(16'hD325); LCD_WR_DATA(16'h31);
//                    LCD_WR_COMMAND(16'hD326); LCD_WR_DATA(16'h03);
//                    LCD_WR_COMMAND(16'hD327); LCD_WR_DATA(16'h5A);
//                    LCD_WR_COMMAND(16'hD328); LCD_WR_DATA(16'h03);
//                    LCD_WR_COMMAND(16'hD329); LCD_WR_DATA(16'h73);
//                    LCD_WR_COMMAND(16'hD32A); LCD_WR_DATA(16'h03);
//                    LCD_WR_COMMAND(16'hD32B); LCD_WR_DATA(16'h94);
//                    LCD_WR_COMMAND(16'hD32C); LCD_WR_DATA(16'h03);
//                    LCD_WR_COMMAND(16'hD32D); LCD_WR_DATA(16'h9F);
//                    LCD_WR_COMMAND(16'hD32E); LCD_WR_DATA(16'h03);
//                    LCD_WR_COMMAND(16'hD32F); LCD_WR_DATA(16'hB3);
//                    LCD_WR_COMMAND(16'hD330); LCD_WR_DATA(16'h03);
//                    LCD_WR_COMMAND(16'hD331); LCD_WR_DATA(16'hB9);
//                    LCD_WR_COMMAND(16'hD332); LCD_WR_DATA(16'h03);
//                    LCD_WR_COMMAND(16'hD333); LCD_WR_DATA(16'hC1);
            
//                    //#R-///////////////////////////////////////////
//                    LCD_WR_COMMAND(16'hD400); LCD_WR_DATA(16'h00);
//                    LCD_WR_COMMAND(16'hD401); LCD_WR_DATA(16'h37);
//                    LCD_WR_COMMAND(16'hD402); LCD_WR_DATA(16'h00);
//                    LCD_WR_COMMAND(16'hD403); LCD_WR_DATA(16'h52);
//                    LCD_WR_COMMAND(16'hD404); LCD_WR_DATA(16'h00);
//                    LCD_WR_COMMAND(16'hD405); LCD_WR_DATA(16'h7B);
//                    LCD_WR_COMMAND(16'hD406); LCD_WR_DATA(16'h00);
//                    LCD_WR_COMMAND(16'hD407); LCD_WR_DATA(16'h99);
//                    LCD_WR_COMMAND(16'hD408); LCD_WR_DATA(16'h00);
//                    LCD_WR_COMMAND(16'hD409); LCD_WR_DATA(16'hB1);
//                    LCD_WR_COMMAND(16'hD40A); LCD_WR_DATA(16'h00);
//                    LCD_WR_COMMAND(16'hD40B); LCD_WR_DATA(16'hD2);
//                    LCD_WR_COMMAND(16'hD40C); LCD_WR_DATA(16'h00);
//                    LCD_WR_COMMAND(16'hD40D); LCD_WR_DATA(16'hF6);
//                    LCD_WR_COMMAND(16'hD40E); LCD_WR_DATA(16'h01);
//                    LCD_WR_COMMAND(16'hD40F); LCD_WR_DATA(16'h27);
//                    LCD_WR_COMMAND(16'hD410); LCD_WR_DATA(16'h01);
//                    LCD_WR_COMMAND(16'hD411); LCD_WR_DATA(16'h4E);
//                    LCD_WR_COMMAND(16'hD412); LCD_WR_DATA(16'h01);
//                    LCD_WR_COMMAND(16'hD413); LCD_WR_DATA(16'h8C);
//                    LCD_WR_COMMAND(16'hD414); LCD_WR_DATA(16'h01);
//                    LCD_WR_COMMAND(16'hD415); LCD_WR_DATA(16'hBE);
//                    LCD_WR_COMMAND(16'hD416); LCD_WR_DATA(16'h02);
//                    LCD_WR_COMMAND(16'hD417); LCD_WR_DATA(16'h0B);
//                    LCD_WR_COMMAND(16'hD418); LCD_WR_DATA(16'h02);
//                    LCD_WR_COMMAND(16'hD419); LCD_WR_DATA(16'h48);
//                    LCD_WR_COMMAND(16'hD41A); LCD_WR_DATA(16'h02);
//                    LCD_WR_COMMAND(16'hD41B); LCD_WR_DATA(16'h4A);
//                    LCD_WR_COMMAND(16'hD41C); LCD_WR_DATA(16'h02);
//                    LCD_WR_COMMAND(16'hD41D); LCD_WR_DATA(16'h7E);
//                    LCD_WR_COMMAND(16'hD41E); LCD_WR_DATA(16'h02);
//                    LCD_WR_COMMAND(16'hD41F); LCD_WR_DATA(16'hBC);
//                    LCD_WR_COMMAND(16'hD420); LCD_WR_DATA(16'h02);
//                    LCD_WR_COMMAND(16'hD421); LCD_WR_DATA(16'hE1);
//                    LCD_WR_COMMAND(16'hD422); LCD_WR_DATA(16'h03);
//                    LCD_WR_COMMAND(16'hD423); LCD_WR_DATA(16'h10);
//                    LCD_WR_COMMAND(16'hD424); LCD_WR_DATA(16'h03);
//                    LCD_WR_COMMAND(16'hD425); LCD_WR_DATA(16'h31);
//                    LCD_WR_COMMAND(16'hD426); LCD_WR_DATA(16'h03);
//                    LCD_WR_COMMAND(16'hD427); LCD_WR_DATA(16'h5A);
//                    LCD_WR_COMMAND(16'hD428); LCD_WR_DATA(16'h03);
//                    LCD_WR_COMMAND(16'hD429); LCD_WR_DATA(16'h73);
//                    LCD_WR_COMMAND(16'hD42A); LCD_WR_DATA(16'h03);
//                    LCD_WR_COMMAND(16'hD42B); LCD_WR_DATA(16'h94);
//                    LCD_WR_COMMAND(16'hD42C); LCD_WR_DATA(16'h03);
//                    LCD_WR_COMMAND(16'hD42D); LCD_WR_DATA(16'h9F);
//                    LCD_WR_COMMAND(16'hD42E); LCD_WR_DATA(16'h03);
//                    LCD_WR_COMMAND(16'hD42F); LCD_WR_DATA(16'hB3);
//                    LCD_WR_COMMAND(16'hD430); LCD_WR_DATA(16'h03);
//                    LCD_WR_COMMAND(16'hD431); LCD_WR_DATA(16'hB9);
//                    LCD_WR_COMMAND(16'hD432); LCD_WR_DATA(16'h03);
//                    LCD_WR_COMMAND(16'hD433); LCD_WR_DATA(16'hC1);

//                    //#G-//////////////////////////////////////////////
//                    LCD_WR_COMMAND(16'hD500); LCD_WR_DATA(16'h00);
//                    LCD_WR_COMMAND(16'hD501); LCD_WR_DATA(16'h37);
//                    LCD_WR_COMMAND(16'hD502); LCD_WR_DATA(16'h00);
//                    LCD_WR_COMMAND(16'hD503); LCD_WR_DATA(16'h52);
//                    LCD_WR_COMMAND(16'hD504); LCD_WR_DATA(16'h00);
//                    LCD_WR_COMMAND(16'hD505); LCD_WR_DATA(16'h7B);
//                    LCD_WR_COMMAND(16'hD506); LCD_WR_DATA(16'h00);
//                    LCD_WR_COMMAND(16'hD507); LCD_WR_DATA(16'h99);
//                    LCD_WR_COMMAND(16'hD508); LCD_WR_DATA(16'h00);
//                    LCD_WR_COMMAND(16'hD509); LCD_WR_DATA(16'hB1);
//                    LCD_WR_COMMAND(16'hD50A); LCD_WR_DATA(16'h00);
//                    LCD_WR_COMMAND(16'hD50B); LCD_WR_DATA(16'hD2);
//                    LCD_WR_COMMAND(16'hD50C); LCD_WR_DATA(16'h00);
//                    LCD_WR_COMMAND(16'hD50D); LCD_WR_DATA(16'hF6);
//                    LCD_WR_COMMAND(16'hD50E); LCD_WR_DATA(16'h01);
//                    LCD_WR_COMMAND(16'hD50F); LCD_WR_DATA(16'h27);
//                    LCD_WR_COMMAND(16'hD510); LCD_WR_DATA(16'h01);
//                    LCD_WR_COMMAND(16'hD511); LCD_WR_DATA(16'h4E);
//                    LCD_WR_COMMAND(16'hD512); LCD_WR_DATA(16'h01);
//                    LCD_WR_COMMAND(16'hD513); LCD_WR_DATA(16'h8C);
//                    LCD_WR_COMMAND(16'hD514); LCD_WR_DATA(16'h01);
//                    LCD_WR_COMMAND(16'hD515); LCD_WR_DATA(16'hBE);
//                    LCD_WR_COMMAND(16'hD516); LCD_WR_DATA(16'h02);
//                    LCD_WR_COMMAND(16'hD517); LCD_WR_DATA(16'h0B);
//                    LCD_WR_COMMAND(16'hD518); LCD_WR_DATA(16'h02);
//                    LCD_WR_COMMAND(16'hD519); LCD_WR_DATA(16'h48);
//                    LCD_WR_COMMAND(16'hD51A); LCD_WR_DATA(16'h02);
//                    LCD_WR_COMMAND(16'hD51B); LCD_WR_DATA(16'h4A);
//                    LCD_WR_COMMAND(16'hD51C); LCD_WR_DATA(16'h02);
//                    LCD_WR_COMMAND(16'hD51D); LCD_WR_DATA(16'h7E);
//                    LCD_WR_COMMAND(16'hD51E); LCD_WR_DATA(16'h02);
//                    LCD_WR_COMMAND(16'hD51F); LCD_WR_DATA(16'hBC);
//                    LCD_WR_COMMAND(16'hD520); LCD_WR_DATA(16'h02);
//                    LCD_WR_COMMAND(16'hD521); LCD_WR_DATA(16'hE1);
//                    LCD_WR_COMMAND(16'hD522); LCD_WR_DATA(16'h03);
//                    LCD_WR_COMMAND(16'hD523); LCD_WR_DATA(16'h10);
//                    LCD_WR_COMMAND(16'hD524); LCD_WR_DATA(16'h03);
//                    LCD_WR_COMMAND(16'hD525); LCD_WR_DATA(16'h31);
//                    LCD_WR_COMMAND(16'hD526); LCD_WR_DATA(16'h03);
//                    LCD_WR_COMMAND(16'hD527); LCD_WR_DATA(16'h5A);
//                    LCD_WR_COMMAND(16'hD528); LCD_WR_DATA(16'h03);
//                    LCD_WR_COMMAND(16'hD529); LCD_WR_DATA(16'h73);
//                    LCD_WR_COMMAND(16'hD52A); LCD_WR_DATA(16'h03);
//                    LCD_WR_COMMAND(16'hD52B); LCD_WR_DATA(16'h94);
//                    LCD_WR_COMMAND(16'hD52C); LCD_WR_DATA(16'h03);
//                    LCD_WR_COMMAND(16'hD52D); LCD_WR_DATA(16'h9F);
//                    LCD_WR_COMMAND(16'hD52E); LCD_WR_DATA(16'h03);
//                    LCD_WR_COMMAND(16'hD52F); LCD_WR_DATA(16'hB3);
//                    LCD_WR_COMMAND(16'hD530); LCD_WR_DATA(16'h03);
//                    LCD_WR_COMMAND(16'hD531); LCD_WR_DATA(16'hB9);
//                    LCD_WR_COMMAND(16'hD532); LCD_WR_DATA(16'h03);
//                    LCD_WR_COMMAND(16'hD533); LCD_WR_DATA(16'hC1);
//                    //#B-///////////////////////////////
//                    LCD_WR_COMMAND(16'hD600); LCD_WR_DATA(16'h00);
//                    LCD_WR_COMMAND(16'hD601); LCD_WR_DATA(16'h37);
//                    LCD_WR_COMMAND(16'hD602); LCD_WR_DATA(16'h00);
//                    LCD_WR_COMMAND(16'hD603); LCD_WR_DATA(16'h52);
//                    LCD_WR_COMMAND(16'hD604); LCD_WR_DATA(16'h00);
//                    LCD_WR_COMMAND(16'hD605); LCD_WR_DATA(16'h7B);
//                    LCD_WR_COMMAND(16'hD606); LCD_WR_DATA(16'h00);
//                    LCD_WR_COMMAND(16'hD607); LCD_WR_DATA(16'h99);
//                    LCD_WR_COMMAND(16'hD608); LCD_WR_DATA(16'h00);
//                    LCD_WR_COMMAND(16'hD609); LCD_WR_DATA(16'hB1);
//                    LCD_WR_COMMAND(16'hD60A); LCD_WR_DATA(16'h00);
//                    LCD_WR_COMMAND(16'hD60B); LCD_WR_DATA(16'hD2);
//                    LCD_WR_COMMAND(16'hD60C); LCD_WR_DATA(16'h00);
//                    LCD_WR_COMMAND(16'hD60D); LCD_WR_DATA(16'hF6);
//                    LCD_WR_COMMAND(16'hD60E); LCD_WR_DATA(16'h01);
//                    LCD_WR_COMMAND(16'hD60F); LCD_WR_DATA(16'h27);
//                    LCD_WR_COMMAND(16'hD610); LCD_WR_DATA(16'h01);
//                    LCD_WR_COMMAND(16'hD611); LCD_WR_DATA(16'h4E);
//                    LCD_WR_COMMAND(16'hD612); LCD_WR_DATA(16'h01);
//                    LCD_WR_COMMAND(16'hD613); LCD_WR_DATA(16'h8C);
//                    LCD_WR_COMMAND(16'hD614); LCD_WR_DATA(16'h01);
//                    LCD_WR_COMMAND(16'hD615); LCD_WR_DATA(16'hBE);
//                    LCD_WR_COMMAND(16'hD616); LCD_WR_DATA(16'h02);
//                    LCD_WR_COMMAND(16'hD617); LCD_WR_DATA(16'h0B);
//                    LCD_WR_COMMAND(16'hD618); LCD_WR_DATA(16'h02);
//                    LCD_WR_COMMAND(16'hD619); LCD_WR_DATA(16'h48);
//                    LCD_WR_COMMAND(16'hD61A); LCD_WR_DATA(16'h02);
//                    LCD_WR_COMMAND(16'hD61B); LCD_WR_DATA(16'h4A);
//                    LCD_WR_COMMAND(16'hD61C); LCD_WR_DATA(16'h02);
//                    LCD_WR_COMMAND(16'hD61D); LCD_WR_DATA(16'h7E);
//                    LCD_WR_COMMAND(16'hD61E); LCD_WR_DATA(16'h02);
//                    LCD_WR_COMMAND(16'hD61F); LCD_WR_DATA(16'hBC);
//                    LCD_WR_COMMAND(16'hD620); LCD_WR_DATA(16'h02);
//                    LCD_WR_COMMAND(16'hD621); LCD_WR_DATA(16'hE1);
//                    LCD_WR_COMMAND(16'hD622); LCD_WR_DATA(16'h03);
//                    LCD_WR_COMMAND(16'hD623); LCD_WR_DATA(16'h10);
//                    LCD_WR_COMMAND(16'hD624); LCD_WR_DATA(16'h03);
//                    LCD_WR_COMMAND(16'hD625); LCD_WR_DATA(16'h31);
//                    LCD_WR_COMMAND(16'hD626); LCD_WR_DATA(16'h03);
//                    LCD_WR_COMMAND(16'hD627); LCD_WR_DATA(16'h5A);
//                    LCD_WR_COMMAND(16'hD628); LCD_WR_DATA(16'h03);
//                    LCD_WR_COMMAND(16'hD629); LCD_WR_DATA(16'h73);
//                    LCD_WR_COMMAND(16'hD62A); LCD_WR_DATA(16'h03);
//                    LCD_WR_COMMAND(16'hD62B); LCD_WR_DATA(16'h94);
//                    LCD_WR_COMMAND(16'hD62C); LCD_WR_DATA(16'h03);
//                    LCD_WR_COMMAND(16'hD62D); LCD_WR_DATA(16'h9F);
//                    LCD_WR_COMMAND(16'hD62E); LCD_WR_DATA(16'h03);
//                    LCD_WR_COMMAND(16'hD62F); LCD_WR_DATA(16'hB3);
//                    LCD_WR_COMMAND(16'hD630); LCD_WR_DATA(16'h03);
//                    LCD_WR_COMMAND(16'hD631); LCD_WR_DATA(16'hB9);
//                    LCD_WR_COMMAND(16'hD632); LCD_WR_DATA(16'h03);
//                    LCD_WR_COMMAND(16'hD633); LCD_WR_DATA(16'hC1);
            
            
            
//                    //#Enable Page0
//                    LCD_WR_COMMAND(16'hF000); LCD_WR_DATA(16'h55);
//                    LCD_WR_COMMAND(16'hF001); LCD_WR_DATA(16'hAA);
//                    LCD_WR_COMMAND(16'hF002); LCD_WR_DATA(16'h52);
//                    LCD_WR_COMMAND(16'hF003); LCD_WR_DATA(16'h08);
//                    LCD_WR_COMMAND(16'hF004); LCD_WR_DATA(16'h00);
//                    //# RGB I/F Setting
//                    LCD_WR_COMMAND(16'hB000); LCD_WR_DATA(16'h08);
//                    LCD_WR_COMMAND(16'hB001); LCD_WR_DATA(16'h05);
//                    LCD_WR_COMMAND(16'hB002); LCD_WR_DATA(16'h02);
//                    LCD_WR_COMMAND(16'hB003); LCD_WR_DATA(16'h05);
//                    LCD_WR_COMMAND(16'hB004); LCD_WR_DATA(16'h02);
//                    //## SDT:
//                    LCD_WR_COMMAND(16'hB600); LCD_WR_DATA(16'h08);
//                    LCD_WR_COMMAND(16'hB500); LCD_WR_DATA(16'h50);//0x6b ???? 480x854       0x50 ???? 480x800
            
//                    //## Gate EQ:
//                    LCD_WR_COMMAND(16'hB700); LCD_WR_DATA(16'h00);
//                    LCD_WR_COMMAND(16'hB701); LCD_WR_DATA(16'h00);
            
//                    //## Source EQ:
//                    LCD_WR_COMMAND(16'hB800); LCD_WR_DATA(16'h01);
//                    LCD_WR_COMMAND(16'hB801); LCD_WR_DATA(16'h05);
//                    LCD_WR_COMMAND(16'hB802); LCD_WR_DATA(16'h05);
//                    LCD_WR_COMMAND(16'hB803); LCD_WR_DATA(16'h05);

//                    //# Inversion: Column inversion (NVT)
//                    LCD_WR_COMMAND(16'hBC00); LCD_WR_DATA(16'h00);
//                    LCD_WR_COMMAND(16'hBC01); LCD_WR_DATA(16'h00);
//                    LCD_WR_COMMAND(16'hBC02); LCD_WR_DATA(16'h00);
            
//                    //# BOE's Setting(default)
//                    LCD_WR_COMMAND(16'hCC00); LCD_WR_DATA(16'h03);
//                    LCD_WR_COMMAND(16'hCC01); LCD_WR_DATA(16'h00);
//                    LCD_WR_COMMAND(16'hCC02); LCD_WR_DATA(16'h00);
            
//                    //# Display Timing:
//                    LCD_WR_COMMAND(16'hBD00); LCD_WR_DATA(16'h01);
//                    LCD_WR_COMMAND(16'hBD01); LCD_WR_DATA(16'h84);
//                    LCD_WR_COMMAND(16'hBD02); LCD_WR_DATA(16'h07);
//                    LCD_WR_COMMAND(16'hBD03); LCD_WR_DATA(16'h31);
//                    LCD_WR_COMMAND(16'hBD04); LCD_WR_DATA(16'h00);
            
//                    LCD_WR_COMMAND(16'hBA00); LCD_WR_DATA(16'h01);
            
//                    LCD_WR_COMMAND(16'hFF00); LCD_WR_DATA(16'hAA);
//                    LCD_WR_COMMAND(16'hFF01); LCD_WR_DATA(16'h55);
//                    LCD_WR_COMMAND(16'hFF02); LCD_WR_DATA(16'h25);
//                    LCD_WR_COMMAND(16'hFF03); LCD_WR_DATA(16'h01);
            
//                    LCD_WR_COMMAND(16'h3500); LCD_WR_DATA(16'h00);
//                    LCD_WR_COMMAND(16'h3600); LCD_WR_DATA(16'h00);
//                    LCD_WR_COMMAND(16'h3a00); LCD_WR_DATA(16'h55);  ////55=16?/////66=18?
//                    LCD_WR_COMMAND(16'h1100);
                    
//                    start_delay_ms(120); // старт затримки 
//                    state     <= 3;

                    
//                end
                3: begin
                    if (delay_done) begin
                        // Пройшла затримка 120 мс
                        LCD_WR_COMMAND(16'h2900 ); 
                        LCD_WR_COMMAND(16'h2c00);
                        pixel_cnt <= 0;
                        state <= 4;
                    end
                end
                4: begin
                    // Заливка екрану червоним кольором
                    if (pixel_cnt < TOTAL_PIXELS) begin
                        LCD_WR_DATA(RED);
                        pixel_cnt <= pixel_cnt + 1;
                    end else begin
                        state <= 4;
                    end
                end
                default: state <= 0;
            endcase
        end
    end
endmodule
