`default_nettype none

module control_unit (
  input wire clk,
  input wire rst_n,
  input wire start,
  input wire [3:0] instr, 

  output wire host_req_mat,
  output wire host_mat_wb,
  output wire load_mmu,
  output wire wm_load_mat,
  output wire [2:0] wm_addr,
);

  // STATES
  localparam[1:0] S_IDLE          = 2'b00;
  localparam[1:0] S_LOAD_MATS  = 2'b01;
  localparam[1:0] S_COMPUTE       = 2'b10;
  localparam[1:0] S_WRITEBACK     = 2'b11;

  reg[1:0] state;
  reg[2:0] mat_elems_loaded;
  reg[1:0] compute_cycles;
  
  // State Machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
      host_req_mat <= 0;
      host_mat_wb <= 0;
      load_mmu <= 0;
      wm_load_mat <= 0;
      wm_addr <= 3'b000;

    end else begin

      case (state)
        S_IDLE:
          if (start) begin
            state <= state + 1;
          end else begin
            state <= state;
          end

          host_req_mat <= 0;
          host_mat_wb <= 0;
          load_mmu <= 0;
          wm_load_mat <= 0;
          wm_addr <= 3'b000;

        S_LOAD_MATS: begin
          if (host_req_mat) begin
            mat_elems_loaded <= mat_elems_loaded + 1;
          end

          if (mat_elems_loaded == 3'b111 ) begin
            state <= state + 1;
            mat_elems_loaded <= 0;
          end

          host_req_mat <= 1;
          host_mat_wb <= 0;
          load_mmu <= 0;
          wm_load_mat <= 1;
          wm_addr <= mat_elems_loaded;
        end

        S_COMPUTE:
          host_req_mat <= 0;
          host_mat_wb <= 0;
          load_mmu <= 1;
          wm_load_mat <= 0;
          wm_addr <= 0;

          if (compute_cycles == 3'b10) begin
            state <= state + 1;
          end

          compute_cycles <= compute_cycles + 1;

        S_WRITEBACK:
          if (mat_elems_loaded == 3'b111 ) begin
            state <= S_IDLE;
          end else begin
            host_mat_wb <= 1;

            host_req_mat <= 0;
            load_mmu <= 0;
            wm_load_mat <= 0;
            wm_addr <= mat_elems_loaded;

            mat_elems_loaded <= mat_elems_loaded + 1;
          end

    end
  end
  
endmodule;
