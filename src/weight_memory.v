`default_nettype none

module weight_memory(
    input wire clk,
    input wire rst,
    input wire mem_ctrl_en,
    input wire [1:0] addr,
    input reg [7:0] rpi_weights,
    output reg [7:0] weight_1,
    output reg [7:0] weight_2,
    output reg [7:0] weight_3,
    output reg [7:0] weight_4
);

reg [7:0] intermediate_memory [3:0];
integer i;

always @(posedge clk) begin
    if (rst) begin
        for (i = 0; i < 8; ++i) begin
            intermediate_memory[i] <= 0;
        end
        weight_1 <= 8'b0;
        weight_2 <= 8'b0;
        weight_3 <= 8'b0;
        weight_4 <= 8'b0;
    end

    if (mem_ctrl_en) begin
        intermediate_memory[addr] <= rpi_weights;
    end

    weight_1 <= intermediate_memory[addr];
    weight_2 <= intermediate_memory[addr + 1];
    weight_3 <= intermediate_memory[addr + 2];
    weight_4 <= intermediate_memory[addr + 3];
end

endmodule