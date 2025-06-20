module spi_master #(
    parameter CLK_FREQ = 50_000_000, // Частота тактового сигналу FPGA (50 МГц)
    parameter SPI_FREQ = 10_000_000  // Частота SPI (10 МГц)
)(
    input wire clk,                  // Системний такт
    input wire rst,                  // Скидання
    input wire start,                // Сигнал для початку зчитування
    input wire [23:0] addr,          // Адреса для зчитування (3 байти)
    input wire [15:0] num_bytes,     // Кількість байтів для зчитування
    output reg [7:0] data_out,       // Зчитані дані
    output reg valid,                // Сигнал готовності даних
    output reg done,                 // Сигнал завершення
    output reg sclk,                 // SPI такт
    output reg cs_n,                 // Chip Select
    output reg mosi,                 // MOSI (DQ0)
    input wire miso                  // MISO (DQ1)
);

    localparam CLK_DIV = CLK_FREQ / (2 * SPI_FREQ); // Дільник для SCLK
    localparam IDLE = 0, CMD = 1, ADDR = 2, DUMMY = 3, DATA = 4, DONE = 5;

    reg [2:0] state;
    reg [7:0] cmd = 8'h0B;          // Fast Read
    reg [23:0] addr_reg;
    reg [15:0] byte_count;
    reg [3:0] bit_count;
    reg [15:0] clk_count;
    reg [7:0] shift_reg;
    reg [3:0] dummy_count;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            sclk <= 0;
            cs_n <= 1;
            mosi <= 0;
            valid <= 0;
            done <= 0;
            clk_count <= 0;
            shift_reg <= 0;
            bit_count <= 0;
            dummy_count <= 0;
            addr_reg <= 0;
            byte_count <= 0;
            data_out <= 0;
        end else begin
            case (state)
                IDLE: begin
                    cs_n <= 1;
                    valid <= 0;
                    done <= 0;
                    if (start) begin
                        state <= CMD;
                        cs_n <= 0;
                        addr_reg <= addr;
                        byte_count <= num_bytes;
                        bit_count <= 0;
                        shift_reg <= cmd;
                    end
                end
                CMD: begin // Надсилання команди
                    if (clk_count < CLK_DIV - 1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= 0;
                        sclk <= ~sclk;
                        if (sclk) begin
                            bit_count <= bit_count + 1;
                            shift_reg <= {shift_reg[6:0], 1'b0};
                            mosi <= shift_reg[7];
                            if (bit_count == 7) begin
                                state <= ADDR;
                                bit_count <= 0;
                                shift_reg <= addr_reg[23:16];
                            end
                        end
                    end
                end
                ADDR: begin // Надсилання адреси
                    if (clk_count < CLK_DIV - 1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= 0;
                        sclk <= ~sclk;
                        if (sclk) begin
                            bit_count <= bit_count + 1;
                            shift_reg <= {shift_reg[6:0], 1'b0};
                            mosi <= shift_reg[7];
                            if (bit_count == 7) begin
                                if (addr_reg[15:0] == 0) begin
                                    state <= DUMMY;
                                    bit_count <= 0;
                                    dummy_count <= 0;
                                end else begin
                                    addr_reg <= {addr_reg[15:0], 8'h0};
                                    shift_reg <= addr_reg[15:8];
                                end
                            end
                        end
                    end
                end
                DUMMY: begin // Dummy cycles (8 тактів)
                    if (clk_count < CLK_DIV - 1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= 0;
                        sclk <= ~sclk;
                        if (!sclk) begin
                            dummy_count <= dummy_count + 1;
                            if (dummy_count == 7) begin
                                state <= DATA;
                                bit_count <= 0;
                                shift_reg <= 0;
                            end
                        end
                    end
                end
                DATA: begin // Зчитування даних
                    if (clk_count < CLK_DIV - 1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= 0;
                        sclk <= ~sclk;
                        if (!sclk) begin
                            shift_reg <= {shift_reg[6:0], miso};
                            bit_count <= bit_count + 1;
                            if (bit_count == 7) begin
                                data_out <= {shift_reg[6:0], miso};
                                valid <= 1;
                                byte_count <= byte_count - 1;
                                bit_count <= 0;
                                if (byte_count == 1) begin
                                    state <= DONE;
                                    valid <= 0;
                                end
                            end else begin
                                valid <= 0;
                            end
                        end
                    end
                end
                DONE: begin
                    cs_n <= 1;
                    done <= 1;
                    state <= IDLE;
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule