`default_nettype none
`timescale 1ns / 1ps

module tb (
    input  logic [15:0] in_bf16,
    output logic [7:0]  out_fp8
);

    initial begin
        $dumpfile("tb_float_convert.vcd");
        $dumpvars(0, tb);
        #1;
    end

    // Instantiate the DUT
    bf16_to_fp8 dut (
        .in_bf16(in_bf16),
        .out_fp8(out_fp8)
    );

endmodule