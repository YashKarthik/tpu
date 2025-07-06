`default_nettype none

module matrix_memory #(
    parameter WIDTH = 8,
    parameter GROUPS = 4  // 16 elements / 4 per group
)(
    input  wire clk,
    input  wire rst,

    // Write interface: group write
    input  wire             write_en,
    input  wire [1:0]       write_addr, // 4 groups: addr 0 to 3
    input  wire [GROUPS*WIDTH-1:0] data_in,   // 4 elements at once

    // Read interface: group read
    input  wire             read_en,
    input  wire [1:0]       read_addr,
    output reg  [GROUPS*WIDTH-1:0] data_out
);

    // 16 total elements
    reg [WIDTH-1:0] memory [0:15];

    integer i;

    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 16; i = i + 1)
                memory[i] <= {WIDTH{1'b0}};
            data_out <= {GROUPS*WIDTH{1'b0}};
        end else begin
            if (write_en) begin
                $display("Writing %d to address %d", data_in, write_addr);
                for (i = 0; i < 4; i = i + 1)
                    memory[{write_addr, 2'b00} + i] <= data_in[i*WIDTH +: WIDTH];
            end
            if (read_en) begin
                $display("Reading from address %d", read_addr);
                for (i = 0; i < 4; i = i + 1)
                    data_out[i*WIDTH +: WIDTH] <= memory[{read_addr, 2'b00} + i];
            end else begin
                data_out <= {GROUPS*WIDTH{1'b0}};
            end
        end
    end

endmodule
