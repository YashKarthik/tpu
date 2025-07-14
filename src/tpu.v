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


    wire const_load  = 1'b0;          // never write
    wire [2:0] load_index = uio_in[2:0];
    wire [7:0] w1, w2, w3, w4;
    wire [7:0] m1, m2, m3, m4;

    memory mem (
        .clk(clk),
        .rst(~rst_n),
        .wm_load_mat(const_load),
        .addr(load_index),
        .rpi_weights(ui_in),
        .weight_1(w1),
        .weight_2(w2),
        .weight_3(w3),
        .weight_4(w4),
        .mat_1(m1),
        .mat_2(m2),
        .mat_3(m3),
        .mat_4(m4)
    );

    assign uo_out   = 8'b0;
    assign uio_out  = 8'b0;
    assign uio_oe   = 8'b10000000;

    wire _unused = &{ena, uio_in[7:3]};

endmodule
