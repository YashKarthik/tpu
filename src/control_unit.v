`default_nettype none

module control_unit (
  input wire clk,
  input wire rst_n,
  input wire start,
  
  // Host interface
  output reg host_req_mat,
  
  // Weight memory interface  
  output reg wm_load_mat,
  output reg [2:0] wm_addr,
  
  // MMU feeding control
  output reg feeding_en,
  output reg [2:0] mmu_cycles,
);

  // STATES
  localparam[1:0] S_IDLE                  = 2'b00;
  localparam[1:0] S_LOAD_MATS             = 2'b01;
  localparam[1:0] S_MMU_FEED_COMPUTE_WB   = 2'b10;

  reg[1:0] state, next_state;
  reg[2:0] mat_elems_loaded;

  // Next state logic
  always @(*) begin
    next_state = state;
    
    case (state)
      S_IDLE: begin
        if (start) begin
            next_state = S_LOAD_MATS;
        end
      end
      
      S_LOAD_MATS: begin
        // All 8 elements loaded (4 for each matrix)
        if (mat_elems_loaded == 3'b111) begin 
            next_state = S_MMU_FEED_COMPUTE_WB;
            mat_elems_loaded <= 0;
        end
      end
      
      S_MMU_FEED_COMPUTE_WB: begin
        /* Cycle 0: Start feeding data
         * Cycle 1: First partial products computed
         * Cycle 2: c00 outputted; c00 = a00×b00 ready
         * Cycle 3: c01 outputted; c01 = a00×b01 ready, c10 = a10×b00 ready
         * Cycle 4: c10 outputted; c11 = a10×b01 ready;
         * Cycle 5: c11 outputted;
         * outputting is staggered since only one output per cycle (tt) 
         * => +1 cycle
         **/
        if (mmu_cycles == 3'b101) begin
          next_state <= S_IDLE;
        end
      end
    endcase
  end
  
  // State Machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
      mat_elems_loaded <= 0;
      mmu_cycles <= 0;
      feeding_en <= 0;,

      host_req_mat <= 0;
      wm_load_mat <= 0;
      wm_addr <= 2'b00;

    end else begin
      state <= next_state;

      case (state)
        S_IDLE:
          host_req_mat <= 0;
          wm_load_mat <= 0;
          wm_addr <= 3'b000;

        S_LOAD_MATS: begin
          if (host_req_mat) begin
            mat_elems_loaded <= mat_elems_loaded + 1;
          end else begin
            mat_elems_loaded <= 0;
          end

          host_req_mat <= 1;
          wm_load_mat <= 1;
          wm_addr <= mat_elems_loaded;
        end

        S_MMU_FEED_COMPUTE_WB:
          feeding_en <= 1;
          host_req_mat <= 0;

          wm_load_mat <= 0;
          wm_addr <= 0;

          mmu_cycles <= mmu_cycles + 1;
      endcase
    end
endmodule;
