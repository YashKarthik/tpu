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

    // Control signal decoding
    wire        load_en        = uio_in[0];
    wire        load_sel_ab    = uio_in[1];
    wire [1:0]  load_index     = uio_in[3:2];
    wire        output_en      = uio_in[4];
    wire [1:0]  output_sel     = uio_in[6:5];

    wire [7:0] out_data;
    wire       done;
    
    wire [7:0] out1;
    wire [7:0] out2;
    wire [7:0] out3;
    wire [7:0] out4;

    weight_memory wmem (
        .clk(clk),
        .rst(~rst_n),
        .mem_ctrl_en(load_en),
        .addr(load_index),
        .rpi_weights(ui_in),
        .weight_1(out1),
        .weight_2(out2),
        .weight_3(out3),
        .weight_4(out4)
    );

    assign uo_out   = out_data;
    assign uio_out  = {done, 7'b0};
    assign uio_oe   = 8'b10000000;

    wire _unused = &{ena, uio_in[7]};

endmodule
