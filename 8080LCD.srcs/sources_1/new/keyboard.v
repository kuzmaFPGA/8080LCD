module keypad_4x4 (
    input wire clk,              // Тактовий сигнал
    input wire rst_n,            // Сигнал скидання (активний низький)
    input wire [3:0] col,        // Стовпці (A12, B11, D10, D9)
    output reg [3:0] row,        // Рядки (D14, D13, C12, E13)
    output reg [3:0] key_code,   // Код натиснутої клавіші
    output reg key_valid         // Сигнал, що клавіша натиснута
);

    // Лічильник для створення затримки сканування
    reg [19:0] scan_counter;
    reg [1:0] scan_state;
    
    // Затримка для дебаунсингу (приблизно 20 мс при 50 МГц)
    localparam DEBOUNCE_CNT = 20'd1_000_000;
    
    // Кодування клавіш (0-F для 4x4 клавіатури)
    reg [3:0] key_map [3:0][3:0];
    
    initial begin
        key_map[0][0] = 4'h1; key_map[0][1] = 4'h2; key_map[0][2] = 4'h3; key_map[0][3] = 4'hA;
        key_map[1][0] = 4'h4; key_map[1][1] = 4'h5; key_map[1][2] = 4'h6; key_map[1][3] = 4'hB;
        key_map[2][0] = 4'h7; key_map[2][1] = 4'h8; key_map[2][2] = 4'h9; key_map[2][3] = 4'hC;
        key_map[3][0] = 4'h0; key_map[3][1] = 4'hF; key_map[3][2] = 4'hE; key_map[3][3] = 4'hD;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            row <= 4'b1110; // Початковий стан: перший рядок активний
            scan_counter <= 20'd0;
            scan_state <= 2'd0;
            key_code <= 4'h0;
            key_valid <= 1'b0;
        end
        else begin
            scan_counter <= scan_counter + 1;
            
            // Сканування рядків
            case (scan_state)
                2'd0: begin // Сканування першого рядка
                    row <= 4'b1110;
                    if (scan_counter >= DEBOUNCE_CNT) begin
                        if (col != 4'b1111) begin
                            key_code <= key_map[0][~col[3:0]];
                            key_valid <= 1'b1;
                        end
                        else begin
                            key_valid <= 1'b0;
                        end
                        scan_counter <= 20'd0;
                        scan_state <= 2'd1;
                    end
                end
                2'd1: begin // Сканування другого рядка
                    row <= 4'b1101;
                    if (scan_counter >= DEBOUNCE_CNT) begin
                        if (col != 4'b1111) begin
                            key_code <= key_map[1][~col[3:0]];
                            key_valid <= 1'b1;
                        end
                        else begin
                            key_valid <= 1'b0;
                        end
                        scan_counter <= 20'd0;
                        scan_state <= 2'd2;
                    end
                end
                2'd2: begin // Сканування третього рядка
                    row <= 4'b1011;
                    if (scan_counter >= DEBOUNCE_CNT) begin
                        if (col != 4'b1111) begin
                            key_code <= key_map[2][~col[3:0]];
                            key_valid <= 1'b1;
                        end
                        else begin
                            key_valid <= 1'b0;
                        end
                        scan_counter <= 20'd0;
                        scan_state <= 2'd3;
                    end
                end
                2'd3: begin // Сканування четвертого рядка
                    row <= 4'b0111;
                    if (scan_counter >= DEBOUNCE_CNT) begin
                        if (col != 4'b1111) begin
                            key_code <= key_map[3][~col[3:0]];
                            key_valid <= 1'b1;
                        end
                        else begin
                            key_valid <= 1'b0;
                        end
                        scan_counter <= 20'd0;
                        scan_state <= 2'd0;
                    end
                end
            endcase
        end
    end

endmodule