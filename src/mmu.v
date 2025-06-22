// Matrix Multiplier Unit for TPU
// Contains core systolic array units
// Does not set project outputs, only outputs staggered elements
module mmu (
    input  wire        clk,
    input  wire        rst,
    input  wire [7:0]  A [0:3],
    input  wire [7:0]  B [0:3],
    output logic [7:0] C [0:3],
    output logic       done
);

    typedef struct packed {
        logic [7:0] a;
        logic [7:0] b;
        logic [15:0] acc;
    } PEState; // state of each PE

    PEState pe00, pe01, pe10, pe11;

    logic [1:0] cycle;

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
