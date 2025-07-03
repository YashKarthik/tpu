module PE (
    input clk,
    input rst,
    input [7:0] a_in,
    input [7:0] b_in,
    input [7:0] c_in,

    output reg [7:0] a_out,
    output reg [7:0] b_out,
    output reg [7:0] c_out
);

    always @(posedge clk or posedge rst) begin
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
