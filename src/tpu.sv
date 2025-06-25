/*
 * Copyright (c) 2025 William
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_tpu (
    input  logic [7:0] ui_in,
    output logic [7:0] uo_out,
    input  logic [7:0] uio_in,
    output logic [7:0] uio_out,
    output logic [7:0] uio_oe,
    input  logic       ena,
    input  logic       clk,
    input  logic       rst_n
);

    logic        load_en        = uio_in[0];
    logic        load_sel_ab    = uio_in[1];
    logic [1:0]  load_index     = uio_in[3:2];
    logic        output_en      = uio_in[4];
    logic [1:0]  output_sel     = uio_in[6:5];
    logic        done;

    controller ctrl (
        .clk(clk),
        .rst(~rst_n),
        .load_en_in(load_en),
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

    logic _unused = &{ena, uio_in[7]};

endmodule 