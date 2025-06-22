// Matrix Multiplier Unit for TPU
// Contains core systolic array units
module mmu (
    input clk,
    input rst,

    input wire load_e, // on whether to load the weights or not
    input wire out_e, // on whether to execute the matrix multiplier

    // input words are 1 byte each
    input [7:0] a_in [1:0],   // a_in[0], a_in[1]: input row of weight matrix
    input [7:0] b_in [1:0],   // b_in[0], b_in[1]: input column of input matrix

    input valid_in,
    output logic valid_out,

    // each element is 1 byte, total of 32 bits
    output [7:0] c_out [1:0][1:0] // accumulator
);

    // Internal registers for each PE
    logic [7:0] a_reg [1:0][1:0];
    logic [7:0] b_reg [1:0][1:0];
    logic [15:0] acc [1:0][1:0];

    // Valid signal delay pipeline
    logic valid_pipe [3:0];

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            // Reset all accumulators and valid pipeline
            for (int i = 0; i < 2; i++) begin
                for (int j = 0; j < 2; j++) begin
                    a_reg[i][j] <= 0;
                    b_reg[i][j] <= 0;
                    acc[i][j] <= 0;
                end
            end
            for (int i = 0; i < 4; i++) valid_pipe[i] <= 0;
        end else begin
            // First row: Load a_in
            a_reg[0][0] <= a_in[0];
            a_reg[0][1] <= a_reg[0][0]; // shift right

            // Second row: shift down
            a_reg[1][0] <= a_reg[0][0];
            a_reg[1][1] <= a_reg[0][1];

            // First column: Load b_in
            b_reg[0][0] <= b_in[0];
            b_reg[1][0] <= b_reg[0][0]; // shift down

            // Second column: shift right
            b_reg[0][1] <= b_in[1];
            b_reg[1][1] <= b_reg[0][1];

            // Multiply-Accumulate
            for (int i = 0; i < 2; i++) begin
                for (int j = 0; j < 2; j++) begin
                    acc[i][j] <= acc[i][j] + a_reg[i][j] * b_reg[i][j];
                end
            end

            // Valid signal propagation
            valid_pipe[0] <= valid_in;
            for (int i = 1; i < 4; i++) valid_pipe[i] <= valid_pipe[i-1];

            valid_out <= valid_pipe[3];
        end
    end

    // Assign outputs when valid (as in execution requested)
    assign c_out[0][0] = load_e ? acc[0][0] : 8'b0;
    assign c_out[0][1] = load_e ? acc[0][1] : 8'b0;
    assign c_out[1][0] = load_e ? acc[1][0] : 8'b0;
    assign c_out[1][1] = load_e ? acc[1][1] : 8'b0;

endmodule
