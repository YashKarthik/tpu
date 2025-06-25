`default_nettype none

module control_unit (
  input wire clk,
  input wire rst_n,
  input wire start,
  input wire [3:0] instr, 

  output wire host_req_mat,
  output wire host_send_mat,
  output wire load_mmu,
  output wire wm_load_mat,
  output wire [2:0] wm_addr,
);
  
  //localparam [3:0] NO_OP          = 3'b000;
  //localparam [3:0] LOAD_WEIGHT    = 3'b001;
  //localparam [3:0] LOAD_INPUTS    = 3'b010;
  //localparam [3:0] COMPUTE        = 3'b100;
  //localparam [3:0] STORE_RES      = 3'b101;
  //localparam [3:0] CAPTURE_RES    = 3'b110;
  //localparam [3:0] CLEAR_ACC      = 3'b111;

  // TODO: figure out bit widths based on number of states
  localparam[1:0] S_IDLE          = 2'b00;
  localparam[1:0] S_LOAD_WEIGHTS  = 2'b01;
  localparam[1:0] S_LOAD_INPUTS   = 2'b10;
  localparam[1:0] S_COMPUTE       = 2'b11;
  localparam[1:0] S_WRITEBACK     = 2'b11;

  reg[1:0] state;
  reg[2:0] mat_elems_loaded;
  reg[1:0] compute_cycles;
  
  // combination block
  // use `=` for assignment
  // using always for if-else stuff
  //always @(*) begin
  //  if (!rst_n) begin
  //    base_address = 0;
  //    load_weight = 0;
  //    load_input = 0;
  //    store = 0;
  //    ext = 0;
  //  end else begin
  //
  //    // defaut values of signals
  //
  //    // state based on instruction
  //    case (instruction_reg[7:5])
  //      default: ;
  //    endcase
  //  end
  //end
  
  
  // state machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      load_weigth <= 0;

    end else begin

      case (state)
        S_IDLE:
          if (start) begin
            state <= state + 1;
          end else begin
            state <= state;
          end

          host_req_mat <= 0;
          wm_load_mat <= 0;
          wm_addr <= 3'b000;
          load_mmu <= 0;

        S_LOAD_MATS: begin
          if (host_req_mat) begin
            mat_elems_loaded <= mat_elems_loaded + 1;
          end

          if (mat_elems_loaded == 3'b111 ) begin
            state <= state + 1;
          end

          host_req_mat <= 1;
          wm_load_mat <= 1;
          wm_addr <= mat_elems_loaded;
          load_mmu <= 0;
        end

        S_COMPUTE:
          host_req_mat <= 0;
          wm_load_mat <= 0;
          wm_addr <= 0;
          load_mmu <= 1;

          if (compute_cycles == 3'b10) begin
            state <= state + 1;
          end

          compute_cycles <= compute_cycles + 1;

        S_WRITEBACK:
          // compute state

    end
  end
  
endmodule;
