module lcd_write_cmd (
    input wire clk,          // Системний тактовий сигнал (8 МГц)
    input wire reset_n,      // Активний низький скид
    input wire start,        // Сигнал запуску запису
    input wire [15:0] cmd,   // 16-бітна команда
    output reg LCD_CS,       // Chip Select (активний низький)
    output reg LCD_RS,       // D/CX (0 - команда)
    output reg LCD_WR,       // WRX (write control)
    output reg LCD_RDX,      // RDX (read control)
    output reg [15:0] LCD_DATA, // Шина даних
    output reg done          // Сигнал завершення запису
);

    // Регістр стану FSM
    reg [2:0] wr_substate;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            wr_substate <= 0;
            LCD_CS <= 1;
            LCD_RS <= 0;
            LCD_WR <= 1;
            LCD_RDX <= 1;
            LCD_DATA <= 16'bz;
            done <= 0;
        end else begin
            case (wr_substate)
                0: begin
                    if (start) begin
                        LCD_CS <= 1;
                        LCD_RS <= 0; // Команда
                        LCD_WR <= 1;
                        LCD_RDX <= 1;
                        LCD_DATA <= 16'bz;
                        done <= 0;
                        wr_substate <= 1;
                    end
                end
                1: begin
                    LCD_CS <= 0;
                    LCD_RS <= 0;
                    LCD_WR <= 0; 
                    LCD_RDX <= 1;
                    LCD_DATA <= cmd;
                    wr_substate <= 2;
                end
                2: begin
                    LCD_CS <= 0;
                    LCD_RS <= 0;
                    LCD_WR <= 1;
                    LCD_RDX <= 1;
                    LCD_DATA <= cmd; // Встановлення команди
                    wr_substate <= 3;
                end
                3: begin
                    LCD_CS <= 1;
                    LCD_RS <= 0;
                    LCD_WR <= 1;
                    LCD_RDX <= 1;
                    LCD_DATA <= 16'bz;
                    done <= 1; // Сигнал завершення
                    wr_substate <= 0;
                end
                default: wr_substate <= 0;
            endcase
        end
    end
endmodule

module lcd_write_cmd_data (
    input wire clk,          // Системний тактовий сигнал (8 МГц)
    input wire reset_n,      // Активний низький скид
    input wire start,        // Сигнал запуску запису
    input wire [15:0] cmd,   // 16-бітна команда
    input wire [15:0] data,  // 16-бітні дані
    output reg LCD_CS,       // Chip Select (активний низький)
    output reg LCD_RS,       // D/CX (0 - команда, 1 - дані)
    output reg LCD_WR,       // WRX (write control)
    output reg LCD_RDX,      // RDX (read control)
    output reg [15:0] LCD_DATA, // Шина даних
    output reg done          // Сигнал завершення запису
);

    // Регістр стану FSM
    reg [3:0] state;
    reg [2:0] wr_substate;

    // Стани FSM
    localparam IDLE = 0, CMD_WRITE = 1, DATA_WRITE = 2, DONE = 3;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state <= IDLE;
            wr_substate <= 0;
            LCD_CS <= 1;
            LCD_RS <= 0;
            LCD_WR <= 1;
            LCD_RDX <= 1;
            LCD_DATA <= 16'bz;
            done <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= CMD_WRITE;
                        wr_substate <= 0;
                        done <= 0;
                    end
                end
                CMD_WRITE: begin
                    case (wr_substate)
                    
                0: begin
                    if (start) begin
                        LCD_CS <= 1;
                        LCD_RS <= 0; // Команда
                        LCD_WR <= 1;
                        LCD_RDX <= 1;
                        LCD_DATA <= 16'bz;
                        done <= 0;
                        wr_substate <= 1;
                    end
                end
                1: begin
                    LCD_CS <= 0;
                    LCD_RS <= 0;
                    LCD_WR <= 0; 
                    LCD_RDX <= 1;
                    LCD_DATA <= cmd;
                    wr_substate <= 2;
                end
                2: begin
                    LCD_CS <= 0;
                    LCD_RS <= 0;
                    LCD_WR <= 1;
                    LCD_RDX <= 1;
                    LCD_DATA <= cmd; // Встановлення команди
                    wr_substate <= 3;
                end
                3: begin
                    LCD_CS <= 1;
                    LCD_RS <= 0;
                    LCD_WR <= 1;
                    LCD_RDX <= 1;
                    LCD_DATA <= 16'bz;
                    state <= DATA_WRITE;
                    wr_substate <= 0;
                end
                endcase
                end
                DATA_WRITE: begin
                    case (wr_substate)
                0: begin
                    if (start) begin
                        LCD_CS <= 1;
                        LCD_RS <= 1; // date
                        LCD_WR <= 1;
                        LCD_RDX <= 1;
                        LCD_DATA <= 16'bz;
                        done <= 0;
                        wr_substate <= 1;
                    end
                end
                1: begin
                    LCD_CS <= 0;
                    LCD_RS <= 1;
                    LCD_WR <= 0; 
                    LCD_RDX <= 1;
                    LCD_DATA <= data;
                    wr_substate <= 2;
                end
                2: begin
                    LCD_CS <= 0;
                    LCD_RS <= 1;
                    LCD_WR <= 1;
                    LCD_RDX <= 1;
                    LCD_DATA <= data; // Встановлення команди
                    wr_substate <= 3;
                end
                3: begin
                    LCD_CS <= 1;
                    LCD_RS <= 1;
                    LCD_WR <= 1;
                    LCD_RDX <= 1;
                    LCD_DATA <= 16'bz;
                    state <= DONE;
                    wr_substate <= 0;
                end
                    endcase
                end
                DONE: begin
                    done <= 1;
                    state <= IDLE;
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule

module lcd_write_cmd_ndata (
    input wire clk,          // Системний тактовий сигнал (8 МГц)
    input wire reset_n,      // Активний низький скид
    input wire start,        // Сигнал запуску запису
    input wire [15:0] cmd,   // 16-бітна команда
    input wire [15:0] data,  // 16-бітні дані (надходять послідовно)
    input wire [31:0] n,     // Кількість даних для запису
    output reg LCD_CS,       // Chip Select (активний низький)
    output reg LCD_RS,       // D/CX (0 - команда, 1 - дані)
    output reg LCD_WR,       // WRX (write control)
    output reg LCD_RDX,      // RDX (read control)
    output reg [15:0] LCD_DATA, // Шина даних
    output reg done          // Сигнал завершення запису
);

    // Регістр стану FSM
    reg [3:0] state;
    reg [2:0] wr_substate;
    reg [31:0] data_count;   // Лічильник записаних даних

    // Стани FSM
    localparam IDLE = 0, CMD_WRITE = 1, DATA_WRITE = 2, DONE = 3;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state <= IDLE;
            wr_substate <= 0;
            data_count <= 0;
            LCD_CS <= 1;
            LCD_RS <= 0;
            LCD_WR <= 1;
            LCD_RDX <= 1;
            LCD_DATA <= 16'bz;
            done <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= CMD_WRITE;
                        wr_substate <= 0;
                        data_count <= 0;
                        done <= 0;
                    end
                end
                CMD_WRITE: begin
                    case (wr_substate)
                        0: begin
                            LCD_CS <= 1;
                            LCD_RS <= 0; // Команда
                            LCD_WR <= 1;
                            LCD_RDX <= 1;
                            LCD_DATA <= 16'bz;
                            wr_substate <= 1;
                        end
                        1: begin
                            LCD_CS <= 0;
                            LCD_RS <= 0;
                            LCD_WR <= 1;
                            LCD_RDX <= 1;
                            LCD_DATA <= 16'bz;
                            wr_substate <= 2;
                        end
                        2: begin
                            LCD_CS <= 0;
                            LCD_RS <= 0;
                            LCD_WR <= 0;
                            LCD_RDX <= 1;
                            LCD_DATA <= 16'bz;
                            wr_substate <= 3;
                        end
                        3: begin
                            LCD_CS <= 0;
                            LCD_RS <= 0;
                            LCD_WR <= 0;
                            LCD_RDX <= 1;
                            LCD_DATA <= cmd;
                            wr_substate <= 4;
                        end
                        4: begin
                            LCD_CS <= 0;
                            LCD_RS <= 0;
                            LCD_WR <= 1;
                            LCD_RDX <= 1;
                            LCD_DATA <= cmd;
                            wr_substate <= 5;
                        end
                        5: begin
                            LCD_CS <= 1;
                            LCD_RS <= 0;
                            LCD_WR <= 1;
                            LCD_RDX <= 1;
                            LCD_DATA <= 16'bz;
                            state <= (n > 0) ? DATA_WRITE : DONE;
                            wr_substate <= 0;
                        end
                    endcase
                end
                DATA_WRITE: begin
                    case (wr_substate)
                        0: begin
                            LCD_CS <= 1;
                            LCD_RS <= 1; // Дані
                            LCD_WR <= 1;
                            LCD_RDX <= 1;
                            LCD_DATA <= 16'bz;
                            wr_substate <= 1;
                        end
                        1: begin
                            LCD_CS <= 0;
                            LCD_RS <= 1;
                            LCD_WR <= 1;
                            LCD_RDX <= 1;
                            LCD_DATA <= 16'bz;
                            wr_substate <= 2;
                        end
                        2: begin
                            LCD_CS <= 0;
                            LCD_RS <= 1;
                            LCD_WR <= 0;
                            LCD_RDX <= 1;
                            LCD_DATA <= 16'bz;
                            wr_substate <= 3;
                        end
                        3: begin
                            LCD_CS <= 0;
                            LCD_RS <= 1;
                            LCD_WR <= 0;
                            LCD_RDX <= 1;
                            LCD_DATA <= data;
                            wr_substate <= 4;
                        end
                        4: begin
                            LCD_CS <= 0;
                            LCD_RS <= 1;
                            LCD_WR <= 1;
                            LCD_RDX <= 1;
                            LCD_DATA <= data;
                            wr_substate <= 5;
                        end
                        5: begin
                            LCD_CS <= 1;
                            LCD_RS <= 1;
                            LCD_WR <= 1;
                            LCD_RDX <= 1;
                            LCD_DATA <= 16'bz;
                            data_count <= data_count + 1;
                            if (data_count + 1 >= n) begin
                                state <= DONE;
                            end
                            wr_substate <= 0;
                        end
                    endcase
                end
                DONE: begin
                    done <= 1;
                    state <= IDLE;
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule