`default_nettype none
`timescale 1ns / 1ps

/* This testbench just instantiates the module and makes some convenient wires
   that can be driven / tested by the cocotb test.py.
*/
module tb (
  input logic clk,
  input logic rst,
  input logic en,
  input logic [2:0] mmu_cycle,

  /* Memory module interface */
  input logic [7:0] weight0,
  input logic [7:0] weight1,
  input logic [7:0] weight2,
  input logic [7:0] weight3,

  input logic [7:0] input0,
  input logic [7:0] input1,
  input logic [7:0] input2,
  input logic [7:0] input3,

  /*  mmu -> feeder  */
  input logic signed [15:0] c00,
  input logic signed [15:0] c01,
  input logic signed [15:0] c10,
  input logic signed [15:0] c11,

  /*  feeder -> mmu */
  output logic clear,
  output logic [7:0] a_data0,
  output logic [7:0] a_data1,
  output logic [7:0] b_data0,
  output logic [7:0] b_data1,

  /*  feeder -> rpi */
  output logic done,
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
    .rst(rst),
    .en(en),
    .mmu_cycle(mmu_cycle),

    .weight0(weight0),
    .weight1(weight1),
    .weight2(weight2),
    .weight3(weight3),

    .input0(input0),
    .input1(input1),
    .input2(input2),
    .input3(input3),

    .c00(c00),
    .c01(c01),
    .c10(c10),
    .c11(c11),

    .clear(clear),
    .a_data0(a_data0),
    .a_data1(a_data1),
    .b_data0(b_data0),
    .b_data1(b_data1),

    .done(done),
    .host_outdata(host_outdata)
  );

endmodule