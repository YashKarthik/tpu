/*
 * Copyright (c) 2025 William
 * SPDX-License-Identifier: Apache-2.0
 */
 
`default_nettype none

module tt_um_tpu (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

    wire        load_en        = uio_in[0];
    wire        load_sel_ab    = uio_in[1];
    wire [1:0]  load_index     = uio_in[3:2];
    wire        output_en      = uio_in[4];
    wire [1:0]  output_sel     = uio_in[6:5];
    wire        done;

    controller ctrl (
        .clk(clk),
        .rst(~rst_n),
        .load_en(load_en),
        .load_sel_ab(load_sel_ab),
        .load_index(load_index),
        .in_data(ui_in),
        .output_en(output_en),
        .output_sel(output_sel),
        .out_data(uo_out),
        .done(done)
    );

    assign uio_out = {done, 7'b0};
    assign uio_oe  = 8'b10000000;

    wire _unused = &{ena, uio_in[7]};

endmodule