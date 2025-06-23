// Matrix Multiplier Unit for TPU
// Contains core systolic array units
// Does not set project outputs, only outputs staggered elements
module mmu (
    input  wire        clk,
    input  wire        rst,
    input  wire [31:0] A_flat,
    input  wire [31:0] B_flat,
    output logic [31:0] C_flat,
    output logic       done
);

    typedef struct packed {
        logic [7:0] a;
        logic [7:0] b;
        logic [15:0] acc;
    } PEState; // state of each PE

    PEState pe00, pe01, pe10, pe11;

    logic [1:0] cycle;

    wire [7:0] A [0:3];
    wire [7:0] B [0:3];
    logic [7:0] C [0:3];

    assign {A[3], A[2], A[1], A[0]} = A_flat;
    assign {B[3], B[2], B[1], B[0]} = B_flat;
    assign C_flat = {C[3], C[2], C[1], C[0]};

    always_ff @(posedge clk) begin
        if (rst) begin
            cycle <= 0;

            pe00.a <= A[0];
            pe00.b <= B[0];
            pe00.acc <= 0;

            pe01.b <= B[1];
            pe01.acc <= 0;

            pe10.a <= A[2];
            pe10.acc <= 0;

            pe11.acc <= 0;
        end else begin
            cycle <= cycle + 1;

            case (cycle)
                2'd0: begin
                    pe00.acc <= pe00.acc + pe00.a * pe00.b;
                    pe01.a <= pe00.a;
                    pe10.b <= pe00.b;
                end
                2'd1: begin
                    pe01.acc <= pe01.acc + pe01.a * pe01.b;
                    pe11.a <= pe10.a;
                    pe11.b <= pe01.b;
                    pe10.acc <= pe10.acc + pe10.a * pe10.b;
                end
                2'd2: begin
                    pe11.acc <= pe11.acc + pe11.a * pe11.b;
                    C[0] <= pe00.acc[7:0];
                    C[1] <= pe01.acc[7:0];
                    C[2] <= pe10.acc[7:0];
                    C[3] <= pe11.acc[7:0];
                    done <= 1;
                end
                default: done <= 0;
            endcase
        end
    end

endmodule
