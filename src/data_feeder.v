`default_nettype none

module data_feeder (
  input wire clk,
  input wire rst_n,
  input wire clear,
  input wire en,
  input wire mmu_cycles,

  input wire [7:0] weight_0,
  input wire [7:0] weight_1,
  input wire [7:0] weight_2,
  input wire [7:0] weight_3

  input wire [7:0] input_0,
  input wire [7:0] input_1,
  input wire [7:0] input_2,
  input wire [7:0] input_3

  output clear,
  output wire [7:0] a_data0,
  output wire [7:0] a_data1,
  output wire [7:0] b_data0,
  output wire [7:0] b_data1,
);

  always (posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      clear <= 1,
      a_data0 <= 0;
      a_data1 <= 0;
      b_data0 <= 0;
      b_data1 <= 0;
    end else begin

      if (en) begin
        case (mmu_cycles)
          0: begin  a_data0 = input_0;   a_data1 = 0;         b_data0 = weight_0;   b_data1 = 0;          end
          1: begin  a_data0 = input_1;   a_data1 = input_2;   b_data0 = weight_2;   b_data1 = weight_1;   end
          2: begin  a_data0 = 0;         a_data1 = input_3;   b_data0 = 0;          b_data1 = weight_3;   end
        endcase
      end else begin
        clear <= 1,
        a_data0 <= 0;
        a_data1 <= 0;
        b_data0 <= 0;
        b_data1 <= 0;
      end

    end
  end

endmodule
