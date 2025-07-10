/*
 * Copyright (c) 2025 William
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_tpu (
    input  wire signed [7:0] ui_in,      // data input
    output wire [7:0] uo_out,     // data output (lower 8 bits of result)
    input  wire [7:0] uio_in,     // control input
    output wire [7:0] uio_out,    // done signal on uio_out[7]
    output wire [7:0] uio_oe,     // only uio_out[7] driven
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

    // Control signal decoding
    wire        load_en        = uio_in[0];
    wire        load_sel_ab    = uio_in[1];
    wire [1:0]  load_index     = uio_in[3:2];
    wire        output_en      = uio_in[4];
    wire [1:0]  output_sel     = uio_in[6:5];

    wire [7:0] out_data;
    wire       done;

    // Instantiate controller
    controller ctrl (
        .clk(clk),
        .rst(~rst_n),
        .load_en(load_en),
        .load_sel_ab(load_sel_ab),
        .load_index(load_index),
        .in_data(ui_in),
        .output_en(output_en),
        .output_sel(output_sel),
        .out_data(out_data),
        .done(done)
    );

    assign uo_out   = out_data;
    assign uio_out  = {done, 7'b0};
    assign uio_oe   = 8'b10000000;

    wire _unused = &{ena, uio_in[7]};

endmodule
