/*
 * Copyright (c) 2025 William
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_tpu (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)

    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  wire        load_en          = uio_in[0];
  wire        load_sel_ab      = uio_in[1]; // selects which matrix, 0 = A, 1 = B 
  wire [1:0]  load_sel_index   = uio_in[3:2]; // selects which element of matrix is being loaded 
  wire        output_en        = uio_in[4];
  wire [1:0]  output_sel       = uio_in[6:5]; // selects which element of C is being output
  wire        done;
  
  controller ctrl (
      .clk(clk),
      .rst(~rst_n),
      .load_en(load_en),
      .load_sel_ab(load_sel_ab),
      .load_index(load_sel_index),
      .in_data(ui_in),
      .output_en(output_en),
      .output_sel(output_sel),
      .out_data(uo_out),
      .done(done)
  );

  // Output data already set in controller??
  assign uio_out = {done, 7'b0};
  assign uio_oe  = 8'b10000000; // Only driving io_out[7]

  // List all unused inputs to prevent warnings
  wire _unused = &{ena, uio_in[7]};

endmodule 