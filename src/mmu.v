module mmu (
    input  wire        clk,
    input  wire        rst,
    input  wire [31:0] A_flat,
    input  wire [31:0] B_flat,
    output reg  [31:0] C_flat,
    output reg         done
);

    wire [7:0] A [0:3];
    wire [7:0] B [0:3];

    assign A[0] = A_flat[7:0];
    assign A[1] = A_flat[15:8];
    assign A[2] = A_flat[23:16];
    assign A[3] = A_flat[31:24];

    assign B[0] = B_flat[7:0];
    assign B[1] = B_flat[15:8];
    assign B[2] = B_flat[23:16];
    assign B[3] = B_flat[31:24];

    reg [15:0] acc00, acc01, acc10, acc11;
    reg [7:0]  a_pipe_01, a_pipe_11;
    reg [7:0]  b_pipe_10, b_pipe_11;

    reg [1:0] cycle;

    always @(posedge clk) begin
        if (rst) begin
            cycle <= 0;
            acc00 <= 0; acc01 <= 0; acc10 <= 0; acc11 <= 0;
            a_pipe_01 <= 0; a_pipe_11 <= 0;
            b_pipe_10 <= 0; b_pipe_11 <= 0;
            C_flat <= 0;
            done <= 0;
        end else begin
            cycle <= cycle + 1;
            done <= 0;

            case (cycle)
                2'd0: begin
                    acc00 <= acc00 + A[0] * B[0];
                    a_pipe_01 <= A[0];
                    b_pipe_10 <= B[0];
                end
                2'd1: begin
                    acc01 <= acc01 + a_pipe_01 * B[1];
                    acc10 <= acc10 + A[2] * b_pipe_10;
                    a_pipe_11 <= A[2];
                    b_pipe_11 <= B[1];
                end
                2'd2: begin
                    acc11 <= acc11 + a_pipe_11 * b_pipe_11;
                    C_flat[7:0]   <= acc00[7:0];
                    C_flat[15:8]  <= acc01[7:0];
                    C_flat[23:16] <= acc10[7:0];
                    C_flat[31:24] <= acc11[7:0];
                    done <= 1;
                end
            endcase
        end
    end

endmodule