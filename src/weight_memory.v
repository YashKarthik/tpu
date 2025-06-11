`default_nettype none

module weight_memory(
    input wire clk,
    input wire rst,
    input wire [15:0] addr,
    output wire [7:0] w1,
    output wire [7:0] w2,
    output wire [7:0] w3,
    output wire [7:0] w4
);

reg [7:0] mem [7:0];

always @(posedge clk) begin
    if (rst) begin
        for (i = 0; i < 8; ++i) begin
            mem[i] <= 8'b0;
        end
        w1 <= 8'b0;
        w2 <= 8'b0;
        w3 <= 8'b0;
        w4 <= 8'b0;
    end
    w1 <= memory[addr];
    w2 <= memory[addr+1];
    w3 <= memory[addr+2];
    w4 <= memory[addr+3];
end

endmodule