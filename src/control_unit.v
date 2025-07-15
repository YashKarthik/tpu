`default_nettype none

module control_unit (
    input wire clk,
    input wire rst,
    input wire [7:0] instrn,

    // Memory interface  
    output reg mem_load_mat,
    output reg [2:0] mem_addr, // Adjusted to 3 bits for matrix and element selection

    // MMU feeding control
    output reg mmu_en,
    output reg [2:0] mmu_cycle // Renamed from mmu_cycle, adjusted to 3 bits
);

    // Instruction decoding
    wire load_en = instrn[0];          // Bit 0: load enable
    wire load_sel_ab = instrn[1];      // Bit 1: select A (weights) or B (inputs)
    wire [1:0] load_index = instrn[3:2]; // Bits 2-3: element index (0-3)
    wire output_en = instrn[4];        // Bit 4: output enable (not used here but decoded)
    wire [1:0] output_sel = instrn[6:5]; // Bits 5-6: output element selection (not used here)
    // Bit 7: ignored as specified

    // STATES
    localparam [1:0] S_IDLE                  = 2'b00;
    localparam [1:0] S_LOAD_MATS             = 2'b01;
    localparam [1:0] S_MMU_FEED_COMPUTE_WB   = 2'b10;

    reg [1:0] state, next_state;
    reg [2:0] mat_elems_loaded;

    // Next state logic
    always @(*) begin
        next_state = state;

        case (state)
            S_IDLE: begin
                if (load_en) begin
                    next_state = S_LOAD_MATS;
                end
            end
            
            S_LOAD_MATS: begin
                // All 8 elements loaded (4 for each matrix)
                if (mat_elems_loaded == 3'b111) begin 
                    next_state = S_MMU_FEED_COMPUTE_WB;
                end
            end
            
            S_MMU_FEED_COMPUTE_WB: begin
                if (mmu_cycle == 3'b101) begin
                    next_state = S_IDLE;
                end
            end

			default begin
				next_state = S_IDLE;
			end
        endcase
    end

    // State Machine
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= S_IDLE;
            mat_elems_loaded <= 0;
            mmu_cycle <= 0;
            mmu_en <= 0;
            mem_load_mat <= 0;
            mem_addr <= 0;
        end else begin
            state <= next_state;

            case (state)
                S_IDLE: begin
                    mat_elems_loaded <= 0;
                    mmu_cycle <= 0;
                    mmu_en <= 0;
                    mem_load_mat <= load_en;
                    if (load_en) begin
                        mem_addr <= {load_sel_ab, load_index}; // Decode instruction
                    end else begin
                        mem_addr <= 0;
                    end
                end

                S_LOAD_MATS: begin
                    if (load_en) begin
                        mat_elems_loaded <= mat_elems_loaded + 1;
                        mem_load_mat <= 1;
                        mem_addr <= {load_sel_ab, load_index}; // Decode instruction
                    end else begin
                        mat_elems_loaded <= 0;
                        mem_load_mat <= 0;
                        mem_addr <= 0;
                    end

                    if (mat_elems_loaded == 3'b111) begin 
                        mat_elems_loaded <= 0;
                    end
                end

                S_MMU_FEED_COMPUTE_WB: begin
                    mmu_en <= 1;
                    mem_load_mat <= 0;
                    mem_addr <= 0;
                    mmu_cycle <= mmu_cycle + 1;
                end
				
				default begin
					mat_elems_loaded <= 0;
                    mmu_cycle <= 0;
                    mmu_en <= 0;
                    mem_load_mat <= load_en;
                    if (load_en) begin
                        mem_addr <= {load_sel_ab, load_index}; // Decode instruction
                    end else begin
                        mem_addr <= 0;
                    end
				end
            endcase
        end
    end

endmodule
