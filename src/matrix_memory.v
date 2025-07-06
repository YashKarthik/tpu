`default_nettype none

// Dual port, 16 byte RAM

module matrix_memory #(
    parameter WIDTH = 8
)(
    input wire clk,
    input wire rst,
    // Port A: Write
    input  wire        write_en,
    input  wire [3:0]  write_addr,
    input  wire [WIDTH-1:0]  data_in,

    // Port B: Read
    input  wire        read_en,
    input  wire [3:0]  read_addr,
    output reg  [WIDTH-1:0]  data_out
);

// 4 matrices × 4 elements each = 16 total elements
reg [WIDTH-1:0] memory [0:15];

// Compute flat address: matrix_index * 4 + element_index
wire [3:0] address = {matrix_index, element_index};

integer i;

always @(posedge clk) begin
    if (rst) begin
        for (i = 0; i < 16; ++i) begin
            memory[i] <= (WIDTH-1)'d0;
        end
        data_out <= (WIDTH-1)'d0;
    end else begin
        if (write_en) begin
            memory[write_addr] <= data_in;
        end
        if (read_en) begin
            data_out <= memory[read_addr];
        end else begin
            data_out <= 8'd0;
        end
    end
end

endmodule