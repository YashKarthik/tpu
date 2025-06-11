`default_nettype none

module control_unit (
  input wire clk,
  input wire rst_n,
  input wire fetch_instr,
  input wire [7:0] instr, 
  input wire [3:0] dma_address,

  output reg [4:0] base_address,
  output reg load_input,
  output reg load_weight,
  output reg valid,
  output reg store_res,
  output reg capture_res
);

  localparam [7:0] NO_OP = 8'b000_00000;
  localparam [7:0] LOAD_WEIGHT = 8'b001_00000;
  localparam [7:0] LOAD_INPUTS = 8'b010_00000;
  localparam [7:0] SET_BASE_ADDR = 8'b011_00000;
  localparam [7:0] COMPUTE = 8'b100_00000;
  localparam [7:0] STORE_RES = 8'b101_00000;
  localparam [7:0] CAPTURE_RES = 8'b110_000000;
  localparam [7:0] CLEAR_ACC = 8'b111_000000;
  
  // Instruction memory, adjust size if needed
  reg [7:0] instruction_mem [0:9];
  reg [7:0] instruction_reg;
  reg [4:0] instruction_pointer;
  
  
  always @(posedge clk) begin 
    if (fetch_ins) begin
      instruction_mem[dma_address] <= instr; 
    end
  end
  
  // combination block
  // use `=` for assignment
  // using always for if-else stuff
  always @(*) begin
    if (!rst_n) begin
      base_address = 0;
      load_weight = 0;
      load_input = 0;
      valid = 0;
      store = 0;
      ext = 0;
    end else begin

      // defaut values
      load_weight = 0;
      load_input = 0;
      ext = 0;
      store = 0; 

      // ctrl signal based on instruction
      case (instruction_reg[7:5])
        SET_BASE_ADDR[7:5] : base_address = instruction_reg[4:0];
        LOAD_WEIGHT[7:5]   : load_weight  = 1;
        LOAD_INPUTS[7:5]   : load_input   = 1;
        COMPUTE[7:5]       : valid        = 1;
        STORE_RES[7:5]     : store_res    = 1;
        CAPTURE_RES[7:5]   : capture_res  = 1;
        default: ;
      endcase
    end
  end


  // state machine

endmodule;
