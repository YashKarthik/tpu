`default_nettype none

module unified_buffer(
    input wire clk,
    input wire rst,
    input store_a1,
    input store_a2,
    input [7:0] a1_mem_0,
    input [7:0] a1_mem_1,
    input [7:0] a2_mem_0,
    input [7:0] a2_mem_1,
    output [7:0] u_mem_1,
    output [7:0] u_mem_2,
    output [7:0] u_mem_3,
    output [7:0] u_mem_4
);

always @(posedge clk) begin
    if (rst) begin
        u_mem_0 <= 0;
        u_mem_1 <= 0;
        u_mem_2 <= 0;
        u_mem_3 <= 0;
    end else begin
        if (store_a1) begin
            u_mem_1 <= a1_mem_0;
            u_mem_2 <= a1_mem_1;
        end
        if (store_a2) begin
            u_mem_3 <= a2_mem_0;
            u_mem_4 <= a2_mem_1;
        end
    end
end


endmodule