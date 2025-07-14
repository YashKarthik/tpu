`default_nettype none

module memory(
    input wire clk,
    input wire rst,
    input wire wm_load_mat,
    input wire [2:0] addr,
    input reg [7:0] rpi_weights,
    output reg [7:0] weight_1,
    output reg [7:0] weight_2,
    output reg [7:0] weight_3,
    output reg [7:0] weight_4,
    output reg [7:0] mat_1,
    output reg [7:0] mat_2,
    output reg [7:0] mat_3,
    output reg [7:0] mat_4
);

reg [7:0] intermediate_memory [7:0];
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
        mat_1 <= 8'b0;
        mat_2 <= 8'b0;
        mat_3 <= 8'b0;
        mat_4 <= 8'b0;
    end

    if (wm_load_mat) begin
        intermediate_memory[addr] <= rpi_weights;
    end

    weight_1 <= intermediate_memory[0];
    weight_2 <= intermediate_memory[1];
    weight_3 <= intermediate_memory[2];
    weight_4 <= intermediate_memory[3];
    mat_1 <= intermediate_memory[4];
    mat_2 <= intermediate_memory[5];
    mat_3 <= intermediate_memory[6];
    mat_4 <= intermediate_memory[7];
end

endmodule