`default_nettype none

module memory (
    input wire clk,
    input wire rst,
    input wire write_en,
    input wire [2:0] addr, // MSB selects matrix (0: weights, 1: inputs), [1:0] selects element
    input wire [7:0] in_data, // Fixed from reg to wire to match tt_um_tpu.v
    output wire [7:0] weights [0:3], // 2x2 matrix A elements, 1 byte each
    output wire [7:0] inputs [0:3]   // 2x2 matrix B elements, 1 byte each
);

    reg [7:0] sram [0:7]; // 8 locations: 0-3 for weights, 4-7 for inputs
    integer i;

    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 8; i = i + 1) begin
                sram[i] <= 8'b0;
            end
            for (i = 0; i < 4; i = i + 1) begin
                weights[i] <= 8'b0;
                inputs[i] <= 8'b0;
            end
        end else if (write_en) begin
            sram[addr] <= in_data;
            $display("%0t: [memory] Write: addr=%b, in_data=%h, sram[%0d]=%h", $time, addr, in_data, addr, in_data);
        end

        // Assign SRAM to output arrays
        weights[0] <= sram[0];
        weights[1] <= sram[1];
        weights[2] <= sram[2];
        weights[3] <= sram[3];
        inputs[0] <= sram[4];
        inputs[1] <= sram[5];
        inputs[2] <= sram[6];
        inputs[3] <= sram[7];
    end

endmodule
