module quad_spi_master #(
    parameter CLK_FREQ = 50_000_000,
    parameter SPI_FREQ = 10_000_000
)(
    input wire clk,
    input wire rst,
    input wire start,
    input wire [23:0] addr,
    input wire [15:0] num_bytes,
    output reg [7:0] data_out,
    output reg valid,
    output reg done,
    output reg sclk,
    output reg cs_n,
    output reg [3:0] dq_out,
    output reg dq_oe,
    inout wire [3:0] dq
);

    localparam CLK_DIV = CLK_FREQ / (2 * SPI_FREQ);
    localparam IDLE = 0, CMD = 1, ADDR = 2, DUMMY = 3, DATA = 4, DONE = 5;

    reg [2:0] state = IDLE;
    reg [7:0] cmd = 8'h6B;
    reg [23:0] addr_reg;
    reg [15:0] byte_count;
    reg [3:0] bit_count;
    reg [15:0] clk_count;
    reg [7:0] shift_reg;
    reg [2:0] dummy_count;

    wire [3:0] dq_in;
    assign dq_in = dq;
    assign dq = dq_oe ? dq_out : 4'bz;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            sclk <= 0;
            cs_n <= 1;
            dq_out <= 4'b0;
            dq_oe <= 0;
            valid <= 0;
            done <= 0;
            clk_count <= 0;
        end else begin
            case (state)
                IDLE: begin
                    cs_n <= 1;
                    valid <= 0;
                    done <= 0;
                    dq_oe <= 0;
                    if (start) begin
                        state <= CMD;
                        cs_n <= 0;
                        addr_reg <= addr;
                        byte_count <= num_bytes;
                        bit_count <= 0;
                        shift_reg <= cmd;
                        dq_oe <= 1;
                    end
                end
                CMD: begin
                    if (clk_count < CLK_DIV - 1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= 0;
                        sclk <= ~sclk;
                        if (sclk) begin
                            bit_count <= bit_count + 1;
                            shift_reg <= {shift_reg[6:0], 1'b0};
                            dq_out <= {3'b0, shift_reg[7]};
                            if (bit_count == 7) begin
                                state <= ADDR;
                                bit_count <= 0;
                                shift_reg <= addr_reg[23:16];
                            end
                        end
                    end
                end
                ADDR: begin
                    if (clk_count < CLK_DIV - 1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= 0;
                        sclk <= ~sclk;
                        if (sclk) begin
                            bit_count <= bit_count + 1;
                            dq_out <= shift_reg[7:4];
                            shift_reg <= {shift_reg[3:0], 4'b0};
                            if (bit_count == 1) begin
                                bit_count <= 0;
                                if (addr_reg[15:0] == 0) begin
                                    state <= DUMMY;
                                    dummy_count <= 0;
                                    dq_oe <= 0;
                                end else begin
                                    addr_reg <= {addr_reg[15:0], 8'h00};
                                    shift_reg <= addr_reg[15:8];
                                end
                            end
                        end
                    end
                end
                DUMMY: begin
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
                DATA: begin
                    if (clk_count < CLK_DIV - 1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= 0;
                        sclk <= ~sclk;
                        if (!sclk) begin
                            shift_reg <= {shift_reg[3:0], dq_in};
                            bit_count <= bit_count + 1;
                            if (bit_count == 1) begin
                                data_out <= {shift_reg[3:0], dq_in};
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
                    dq_oe <= 0;
                    state <= IDLE;
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule