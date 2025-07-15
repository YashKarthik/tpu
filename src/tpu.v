/*
 * Copyright (c) 2025 William
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_tpu (
    input  wire [7:0] ui_in,      // data input
    output wire [7:0] uo_out,     // data output (lower 8 bits of result)
    input  wire [7:0] uio_in,     // control input
    output wire [7:0] uio_out,    // done signal on uio_out[7]
    output wire [7:0] uio_oe,     // only uio_out[7] driven
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

    wire instruction = uio_in[0];

    wire compute_en; // internal signal
    reg clear; // reset of PEs only
    wire [2:0] mem_addr; // 3-bit address for matrix and element selection
    reg mem_load_mat;

    wire [2:0] mmu_cycle; // compute/output cycle count, minimum 5, maximum ???

    wire [7:0] weight0, weight1, weight2, weight3;
    wire [7:0] input0, input1, input2, input3;

    wire [15:0] outputs [0:3]; // raw accumulations (16-bit)
    wire [7:0] out_data; // sent to CPU
    // Ports of the systolic Array
    wire [7:0] a_data0, b_data0, a_data1, b_data1;

    wire done;

    // Module Instantiations
    memory mem (
        .clk(clk),
        .rst(~rst_n),
        .write_en(mem_load_mat),
        .addr(mem_addr),
        .in_data(ui_in),
        .weight0(weight0), .weight1(weight1), .weight2(weight2), .weight3(weight3),
        .input0(input0), .input1(input1), .input2(input2), .input3(input3)
    );

    control_unit central_ctrl (
        .clk(clk),
        .rst(~rst_n),
        .instrn(instruction),
        .mem_load_mat(mem_load_mat),
        .mem_addr(mem_addr),
        .mmu_en(compute_en),
        .mmu_cycle(mmu_cycle)
    );

    systolic_array_2x2 mmu (
        .clk(clk),
        .rst(~rst_n),
        .clear(clear),
        .a_data0(a_data0),
        .a_data1(a_data1),
        .b_data0(b_data0),
        .b_data1(b_data1),
        .c00(outputs[0]), 
        .c01(outputs[1]), 
        .c10(outputs[2]), 
        .c11(outputs[3])
    );

    mmu_feeder compute_ctrl (
        .clk(clk),
        .rst(~rst_n),
        .en(compute_en),
        .mmu_cycle(mmu_cycle),
        .weight0(weight0), .weight1(weight1), .weight2(weight2), .weight3(weight3),
        .input0(input0), .input1(input1), .input2(input2), .input3(input3),
        .c00(outputs[0]), 
        .c01(outputs[1]), 
        .c10(outputs[2]), 
        .c11(outputs[3]),
        .clear(clear),
        .a_data0(a_data0),
        .a_data1(a_data1),
        .b_data0(b_data0),
        .b_data1(b_data1),
        .done(done),
        .host_outdata(out_data)
    );

    assign uo_out = out_data;
    assign uio_out = {done, 7'b0};
    assign uio_oe = 8'b10000000;

    wire _unused = &{ena, uio_in[7:3]};

endmodule
