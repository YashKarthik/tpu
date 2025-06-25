`default_nettype none
`timescale 1ns / 1ps

/* This testbench just instantiates the module and makes some convenient wires
   that can be driven / tested by the cocotb test.py.
*/module tb ();

  // Dump the signals to a VCD file. You can view it with gtkwave or surfer.
  initial begin
    $dumpfile("tb.vcd");
    $dumpvars(0, tb);
    #1;
  end

  // Clock and reset generation
  logic clk;
  logic rst_n;
  logic ena;
  logic [7:0] ui_in;
  logic [7:0] uio_in;
  logic [7:0] uo_out;
  logic [7:0] uio_out;
  logic [7:0] uio_oe;

  // Instantiate DUT
  tt_um_tpu tpu_project (
      .ui_in  (ui_in),
      .uo_out (uo_out),
      .uio_in (uio_in),
      .uio_out(uio_out),
      .uio_oe (uio_oe),
      .ena    (ena),
      .clk    (clk),
      .rst_n  (rst_n)
  );

endmodule
