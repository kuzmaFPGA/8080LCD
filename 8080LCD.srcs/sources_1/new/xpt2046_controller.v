module xpt2046(
    Clk50m,
    Rst_n,
    EN,
    X_Value,
    Y_Value,
    Get_Flag,
    
    PenIrq_n,
    DCLK,
    DIN,
    DOUT,
    CS_N,
    BUSY
);

    input Clk50m;
    input Rst_n;
    input EN;
    output reg [11:0]X_Value;
    output reg [11:0]Y_Value;
    
    output reg Get_Flag;
    
    input PenIrq_n;
    input BUSY;
    output reg DCLK;
    output reg DIN;
    output reg CS_N;
    input  DOUT;
    
    wire pen_flag;
    wire pen_state;
    
    reg [4:0]DIV_CNT;//Get twice the DCLK clock sampling clock to produce DCLK
    reg [5:0]CLK_GEN_CNT;//Generate a DCLK clock counter
    reg [5:0]CONV_CNT;//How many times is recorded?
    
    reg [19:0]PEN_CNT;
    
    reg DCLK2X;
    reg CONV_DONE;
    reg [11:0]Dtmp;
    reg EN_CONV;
    
    reg [16:0]tmp_X_Value,tmp_Y_Value;
    reg [11:0]X_MAX,X_MIN,Y_MAX,Y_MIN;
    reg r_Get_Flag;
    
    localparam S = 1'B1; // start bit
    localparam MODE = 1'B0; // Sampling accuracy
    localparam SER_DFR = 1'B0; // single-end / differential sampling mode
    localparam PD = 2'B00; // power consumption control
    parameter CONV_TIMES = 36;  //Calculate a mean for every time conversion
    parameter FILTER_PARAM = 4; //Remove 4 digits by 16 ==
    
    parameter CNT_TOP = 20'D499999; //                
    
    wire [2:0]ADDR; //Sampling channel control
    
    assign ADDR = (CONV_CNT[0])?3'b101:3'b001;//The CONV_CNT value is an even number, select the measurement X channel
    
    wire cnt_full;//PEN pin signal filter counter count full flag
    
    //PEN Pin Delay Filter Counter
    always@(posedge Clk50m or negedge Rst_n)
    if(!Rst_n)
        PEN_CNT <= 20'd0;
    else if(!PenIrq_n)begin //Person's key
        if(cnt_full)    //Be returned to zero
            PEN_CNT <= 20'd0;
        else    //Be accumulated
            PEN_CNT <= PEN_CNT + 1'b1;
    end else    //The stroke is high, the count is forced
        PEN_CNT <= 20'd0;
        
    assign cnt_full = (PEN_CNT == CNT_TOP);
    
    assign pen_state = cnt_full;//When the PeniRQ_N pin is low, each count is full of Pen_State signals, triggering a 36 samples

    //2x DCLK sampling clock frequency division counter   
    always@(posedge Clk50m or negedge Rst_n)
    if(!Rst_n)
        DIV_CNT <= 5'd0;
    else if(EN_CONV)begin
        if(DIV_CNT == 5'd24)
            DIV_CNT <= 5'd0;
        else 
            DIV_CNT <= DIV_CNT + 1'b1;
    end
    else
        DIV_CNT <= 5'd0;
    
    //Generate a 2x DCLK enable clock
    always@(posedge Clk50m or negedge Rst_n)
    if(!Rst_n)
        DCLK2X <= 1'b0;
    else if(DIV_CNT == 5'd24)
        DCLK2X <= 1'b1;
    else
        DCLK2X <= 1'b0;

    //Techniques for 2x DCLK sampling clocks to produce a sequence machine basic sequence
    always@(posedge Clk50m or negedge Rst_n)
    if(!Rst_n)
        CLK_GEN_CNT <= 6'b0;
    else if(EN_CONV)begin
        if(DCLK2X)begin
            if(CLK_GEN_CNT == 6'D45) // After counting to 46, return to 16 start re-counting
                CLK_GEN_CNT <= 6'd16;
            else
                CLK_GEN_CNT <= CLK_GEN_CNT + 1'b1;
        end
    end
    else
        CLK_GEN_CNT <= 6'b0;

    //Control the sequence according to the CLK_GEN_CNT value, send the control word and read the resulting result.
    always@(posedge Clk50m or negedge Rst_n)
    if(!Rst_n)begin
        DIN <= 1'b1;
        Dtmp <= 12'd0;
        DCLK <= 1'd0;
        CONV_CNT <= 6'd0;
    end     
    else if(EN_CONV)begin
        if(DCLK2X)begin
            case(CLK_GEN_CNT)
                0:begin DIN <= S; DCLK <= 1'B0; end // Send the first conversion start bit
                1:begin DCLK <= 1'b1; end
                
                2:begin DIN <= ADDR[2]; DCLK <= 1'B0; end // Send A2
                3:begin DCLK <= 1'b1; end
                
                4:begin DIN <= ADDR[1]; DCLK <= 1'B0; end // Send A1
                5:begin DCLK <= 1'b1; end
                
                6:begin DIN <= ADDR[0]; DCLK <= 1'B0; end // Send A0
                7:begin DCLK <= 1'b1; end
                
                8:begin DIN <= MODE; DCLK <= 1'B0; end // Send Sampling Accuracy Setting Bit
                9:begin DCLK <= 1'b1; end
                
                10:begin DIN <= SER_DFR; DCLK <= 1'B0; end // Send ADC input mode
                11:begin DCLK <= 1'b1;end
                
                12:begin DIN <= PD[1]; DCLK <= 1'B0; end // Send Power Control Bit PD1
                13:begin DCLK <= 1'b1; end
                
                14:begin DIN <= PD[0]; DCLK <= 1'B0; end // Send Power Control Bit PD0
                15:begin DCLK <= 1'b1; end
                
                16:begin DIN <= 0; DCLK <= 1'B0; end // Waiting for the Sampling Circuit Work
                17:begin DCLK <= 1'b1; end
                
                18:begin DIN <= 0; DCLK <= 1'b0; end
                19:begin Dtmp[11] <= DOUT; DCLK <= 1'B1; end // Read 11th-bit conversion result
                
                20:begin DIN <= 0; DCLK <= 1'b0; end
                21:begin Dtmp[10] <= DOUT; DCLK <= 1'B1; end // read 10th conversion results
                
                22:begin DIN <= 0; DCLK <= 1'b0; end
                23:begin Dtmp[9] <= DOUT; DCLK <= 1'B1; end // read the 9th conversion result
                
                24:begin DIN <= 0; DCLK <= 1'b0; end
                25:begin Dtmp[8] <= DOUT;DCLK <= 1'B1; end // read eight-bit conversion results
                
                26:begin DIN <= 0; DCLK <= 1'b0; end
                27:begin Dtmp[7] <= DOUT; DCLK <= 1'B1; end // read 7-bit conversion result
                
                28:begin DIN <= 0; DCLK <= 1'b0; end
                29:begin Dtmp[6] <= DOUT; DCLK <= 1'B1; end // read the sixth-bit conversion result
                
                30:begin DIN <= S; DCLK <= 1'B0; end // Send the starting position of the next conversion
                31:begin Dtmp[5] <= DOUT; DCLK <= 1'B1; end // read the 5th transition result
                
                32:begin DIN <= ADDR[2]; DCLK <= 1'B0; end // Send a next conversion A2
                33:begin Dtmp[4] <= DOUT; DCLK <= 1'b1; end
                
                34:begin DIN <= ADDR[1]; DCLK <= 1'B0; end // Send the next conversion A1
                35:begin Dtmp[3] <= DOUT; DCLK <= 1'b1; end
                
                36:begin DIN <= ADDR[0]; DCLK <= 1'B0; end // Send the next conversion A0
                37:begin Dtmp[2] <= DOUT; DCLK <= 1'b1; end
                
                38:begin DIN <= MODE; DCLK <= 1'B0; end // Send the next conversion sampling accuracy setting bit
                39:begin Dtmp[1] <= DOUT; DCLK <= 1'b1; end
                
                40:begin DIN <= SER_DFR; DCLK <= 1'B0; end // Send Next Sampling ADC Input Model Bit
                41:begin Dtmp[0] <= DOUT; DCLK <= 1'b1; CONV_CNT <= CONV_CNT + 1'b1; end
        
                42:begin DIN <= PD[1]; DCLK <= 1'B0; end // Send Power Control Bit PD1
                43:begin DCLK <= 1'b1; end
                
                44:begin DIN <= PD[0]; DCLK <= 1'B0; end // Send Power Control Bit PD0
                45:begin DCLK <= 1'b1; CONV_DONE <= 1'b1; end   
            endcase
        end else
            CONV_DONE <= 1'b0;
    end else if(!EN_CONV)begin
        CONV_CNT <= 0;
        CONV_DONE <= 1'b0;
    end
    
    //Tired of sample results of 18 samples in 36 samples
    always@(posedge Clk50m or negedge Rst_n)
    if(!Rst_n)
        tmp_X_Value <= 17'd0;
    else if(EN_CONV == 1'b0)
        tmp_X_Value <= 17'd0;
    else if(CONV_DONE && CONV_CNT[0])//The conversion is completed, the conversion count is odd, and the conversion result is accumulated to the X temporary register.
        tmp_X_Value <= tmp_X_Value + Dtmp;

    //Record the maximum value of 18 X channel sampling      
    always@(posedge Clk50m or negedge Rst_n)
    if(!Rst_n)
        X_MAX <= 12'd0;
    else if(EN_CONV == 1'b0)
        X_MAX <= 12'd0;
    else if(CONV_DONE && CONV_CNT[0])begin//The conversion is completed, the conversion count is odd, determined whether the current value is greater than the maximum value
        if(Dtmp > X_MAX)
            X_MAX <= Dtmp;
        else
            X_MAX <= X_MAX;
    end
    
    //Record the minimum of 18 X channel sampling      
    always@(posedge Clk50m or negedge Rst_n)
    if(!Rst_n)
        X_MIN <= 12'd0;
    else if(EN_CONV == 1'b0)
        X_MIN <= 12'd4095;
    else if(CONV_DONE && CONV_CNT[0])begin//The conversion is completed, the conversion count is odd, determined if the current value is less than the stored minimum value
        if(Dtmp < X_MIN)
            X_MIN <= Dtmp;
        else
            X_MIN <= X_MIN;
    end
    
    //Accumulate 36 samples of Y channel in 36 samples
    always@(posedge Clk50m or negedge Rst_n)
    if(!Rst_n)
        tmp_Y_Value <= 17'd0;
    else if(EN_CONV == 1'b0)
        tmp_Y_Value <= 17'd0;
    else if(CONV_DONE && (!CONV_CNT[0]))//The conversion is completed, the conversion count is an even number, and the conversion result is accumulated to the Y temporary register.
        tmp_Y_Value <= tmp_Y_Value + Dtmp;
    
    //Record the maximum value of 18 Y channel sampling  
    always@(posedge Clk50m or negedge Rst_n)
    if(!Rst_n)
        Y_MAX <= 12'd0;
    else if(EN_CONV == 1'b0)
        Y_MAX <= 12'd0;
    else if(CONV_DONE && (~CONV_CNT[0]))begin//The conversion is completed, the conversion count is odd, determined whether the current value is greater than the maximum value
        if(Dtmp > Y_MAX)
            Y_MAX <= Dtmp;
        else
            Y_MAX <= Y_MAX;
    end
    
    //Record the minimum value of 18 Y channel sampling
    always@(posedge Clk50m or negedge Rst_n)
    if(!Rst_n)
        Y_MIN <= 12'd0;
    else if(EN_CONV == 1'b0)
        Y_MIN <= 12'd4095;
    else if(CONV_DONE && (~CONV_CNT[0]))begin//The conversion is completed, the conversion count is odd, determined if the current value is less than the stored minimum value
        if(Dtmp < Y_MIN)
            Y_MIN <= Dtmp;
        else
            Y_MIN <= Y_MIN;
    end
    
    //Enable 36 transitions
    always@(posedge Clk50m or negedge Rst_n)
    if(!Rst_n)
        EN_CONV <= 1'b0;
    else if(EN)begin
        if(pen_state)
            EN_CONV <= 1'b1;
        else if((CONV_CNT == CONV_TIMES) && CLK_GEN_CNT == 29)//Conversion completion, aligned 15 cycle timing
            EN_CONV <= 1'b0;
        else
            EN_CONV <= EN_CONV;
    end
    else
        EN_CONV <= 1'b0;

    //
    always@(posedge Clk50m or negedge Rst_n)
    if(!Rst_n)
        r_Get_Flag <= 1'b0;
    else if((CONV_CNT == CONV_TIMES) && CONV_DONE)
            r_Get_Flag <= 1'b1;
    else
        r_Get_Flag <= 1'b0;
        
    always@(posedge Clk50m)
        Get_Flag <= r_Get_Flag;
    
    always@(posedge Clk50m)
        CS_N <= ~EN_CONV;
        
    reg [11:0]r_X_Value,r_Y_Value;
    
    //Calculate the current X mean, X mean = (18 cumulative value - maximum - minimum) / 16
    always@(posedge Clk50m or negedge Rst_n)
    if(!Rst_n)
        r_X_Value <= 12'd0;
    else if(r_Get_Flag)
        r_X_Value <= (tmp_X_Value - X_MAX - X_MIN) >> FILTER_PARAM;
    else
        r_X_Value <= r_X_Value;
    
    //Calculate the current Y average, y average = (18 time accumulated value - maximum - minimum) / 16  
    always@(posedge Clk50m or negedge Rst_n)
    if(!Rst_n)
        r_Y_Value <= 12'd0;
    else if(r_Get_Flag)
        r_Y_Value <= (tmp_Y_Value - Y_MAX - Y_MIN) >> FILTER_PARAM;
    else
        r_Y_Value <= r_Y_Value;

    //Store the last X result as an output, in order to filter out the last conversion result, because the last conversion result is a press release time, the result is not stable
    always@(posedge Clk50m or negedge Rst_n)
    if(!Rst_n)
        X_Value <= 12'd0;
    else if(r_Get_Flag)
        X_Value <= r_X_Value;

    //Store the last Y result as an output, in order to filter out the last conversion result, because the last conversion result is time-free, the result is not stable       
    always @(posedge Clk50m or negedge Rst_n)
    if(!Rst_n)
        Y_Value <= 12'd0;
    else if(r_Get_Flag)
        Y_Value <= r_Y_Value;

endmodule