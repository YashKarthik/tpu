module PE #(
    parameter WIDTH = 8
)(
    input wire clk,
    input wire rst,

    input wire [WIDTH-1:0] a_in,
    input wire [WIDTH-1:0] b_in,
    input wire valid_in,

    output reg [WIDTH-1:0] a_out,
    output reg [WIDTH-1:0] b_out,
    output reg valid_out,

    output reg [2*WIDTH-1:0] c_out
);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            c_out     <= 0;
            a_out     <= 0;
            b_out     <= 0;
            valid_out <= 0;
        end else begin;
            if (valid_in) begin
                c_out     <= c_out + a_in * b_in;
                a_out     <= a_in;
                b_out     <= b_in;
                valid_out <= 1;
            end else begin
                valid_out <= 0;
            end
        end
    end
endmodule
