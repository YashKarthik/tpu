// A single processing element
module PE (
    input  logic         clk,
    input  logic         rst,
    input  logic [7:0]   a_in,
    input  logic [7:0]   b_in,
    input  logic [7:0]  c_in,       // Accumulated C value from previous PE/initial 0

    output logic [7:0]   a_out,
    output logic [7:0]   b_out,
    output logic [7:0]  c_out       // Accumulated C value to next PE/final output
);

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            a_out <= 0;
            b_out <= 0;
            c_out <= 0;
        end else begin
            a_out <= a_in;
            b_out <= b_in;
            c_out <= c_in + a_in * b_in;
        end
    end

endmodule