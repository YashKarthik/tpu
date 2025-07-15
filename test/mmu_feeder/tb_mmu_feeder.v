`default_nettype none
`timescale 1ns / 1ps

/* This testbench just instantiates the module and makes some convenient wires
   that can be driven / tested by the cocotb test.py.
*/
module tb (
  input logic clk,
  input logic rst_n,
  input logic en,
  input logic [2:0] mmu_cycles,

  /* Memory module interface */
  input logic [7:0] weight_0,
  input logic [7:0] weight_1,
  input logic [7:0] weight_2,
  input logic [7:0] weight_3,

  input logic [7:0] input_0,
  input logic [7:0] input_1,
  input logic [7:0] input_2,
  input logic [7:0] input_3,

  /*  mmu -> feeder  */
  input logic [7:0] c_0,
  input logic [7:0] c_1,
  input logic [7:0] c_2,
  input logic [7:0] c_3,

  /*  feeder -> mmu */
  output logic clear,
  output logic [7:0] a_data0,
  output logic [7:0] a_data1,
  output logic [7:0] b_data0,
  output logic [7:0] b_data1,

  /*  feeder -> rpi */
  output logic host_mat_wb,
  output logic [7:0] host_outdata
);

  // Dump the signals to a VCD file. You can view it with gtkwave or surfer.
  initial begin
    $dumpfile("tb_mmu_feeder.vcd");
    $dumpvars(0, tb);
    #1;
  end

  // Instantiate the MMU feeder module
  mmu_feeder dut (
    .clk(clk),
    .rst_n(rst_n),
    .en(en),
    .mmu_cycles(mmu_cycles),

    .weight_0(weight_0),
    .weight_1(weight_1),
    .weight_2(weight_2),
    .weight_3(weight_3),

    .input_0(input_0),
    .input_1(input_1),
    .input_2(input_2),
    .input_3(input_3),

    .c_0(c_0),
    .c_1(c_1),
    .c_2(c_2),
    .c_3(c_3),

    .clear(clear),
    .a_data0(a_data0),
    .a_data1(a_data1),
    .b_data0(b_data0),
    .b_data1(b_data1),

    .host_mat_wb(host_mat_wb),
    .host_outdata(host_outdata)
  );

endmodule