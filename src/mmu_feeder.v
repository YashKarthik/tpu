`default_nettype none

module mmu_feeder (
  input wire clk,
  input wire rst_n,
  input wire en,
  input wire [2:0] mmu_cycles,

  input wire [7:0] weight_0,
  input wire [7:0] weight_1,
  input wire [7:0] weight_2,
  input wire [7:0] weight_3

  input wire [7:0] input_0,
  input wire [7:0] input_1,
  input wire [7:0] input_2,
  input wire [7:0] input_3,

  input wire [7:0] c_0,
  input wire [7:0] c_1,
  input wire [7:0] c_2,
  input wire [7:0] c_3

  output clear,
  output reg [7:0] a_data0,
  output reg [7:0] a_data1,
  output reg [7:0] b_data0,
  output reg [7:0] b_data1,

  output wire host_mat_wb,
  output reg [7:0] host_outdata,
);

  reg [7:0] out_buf;
  assign host_mat_wb = en && (mmu_cycles >= 3'b010) && (mmu_cycles <= 3'b101);

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      clear <= 1,
      a_data0 <= 0;
      a_data1 <= 0;
      b_data0 <= 0;
      b_data1 <= 0;

      host_outdata <= 0;
    end else begin

      if (en) begin
        /* Cycle 0: Start feeding data
         * Cycle 1: First partial products computed
         * Cycle 2: c00 outputted; c00 = a00×b00 ready
         * Cycle 3: c01 outputted; c01 = a00×b01 ready, c10 = a10×b00 ready
         * Cycle 4: c10 outputted; c11 = a10×b01 ready;
         * Cycle 5: c11 outputted;
         * outputting is staggered since only one output per cycle (tt) 
         * => +1 cycle
         **/
        case (mmu_cycle)
          3'b000: begin
            a_data0  <= input_0;   
            a_data1  <= 8'b0;         
            b_data0  <= weight_0;   
            b_data1  <= 8'b0;          

            host_outdata <= 0;
          end

          3'b001: begin
            a_data0  <= input_1;   
            a_data1  <= input_2;   
            b_data0  <= weight_2;   
            b_data1  <= weight_1;   

            host_outdata <= 0;
          end

          3'b010: begin
            a_data0  <= 8'b0;         
            a_data1  <= input_3;   
            b_data0  <= 8'b0;          
            b_data1  <= weight_3;   

            host_outdata <= c0;
          end

          3'b011: begin
            a_data0 <= 0;      
            a_data1 <= 0;
            b_data0 <= 0;       
            b_data1 <= 0;   

            host_outdata <= c1;
            out_buf <= c2;
          end

          3'b100: begin
            a_data0 <= 0;      
            a_data1 <= 0;
            b_data0 <= 0;       
            b_data1 <= 0;   

            host_outdata <= c2;
            out_buf <= c3;
          end

          3'b101: begin
            a_data0 <= 0;      
            a_data1 <= 0;
            b_data0 <= 0;       
            b_data1 <= 0;   

            host_outdata <= c3;
            out_buf <= 0;
          end

          default: begin
            a_data0 <= 8'b0;
            a_data1 <= 8'b0;
            b_data0 <= 8'b0;
            b_data1 <= 8'b0;
            
            host_outdata <= 0;
            out_buf <= 0;
          end
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
