module controller (
    input  logic         clk,
    input  logic         rst,
    input  logic         load_en_in, // Renamed to avoid clash with internal signal if you wish
    input  logic         load_sel_ab,
    input  logic [1:0]   load_index,
    input  logic [7:0]   in_data,
    input  logic         output_en,
    input  logic [1:0]   output_sel,
    output logic [7:0]   out_data,
    output logic         done // Done signal from mmu
);

    typedef logic [7:0] matrix2x2_t [2][2];

    matrix2x2_t A, B, C;
    logic [3:0] a_loaded, b_loaded;
    logic       start_mmu; // Signal to mmu

    typedef enum logic [1:0] {
        IDLE_WAIT_LOAD,
        CALCULATING_START, // State to pulse 'start_mmu'
        WAITING_FOR_MMU_DONE
    } controller_state_t;

    controller_state_t current_state, next_state;

    // Instantiate the new systolic mmu
    mmu systolic_array (
        .clk(clk),
        .rst(rst),
        .start(start_mmu),
        .A(A),
        .B(B),
        .C(C),
        .done(done)
    );

    // State register
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            current_state <= IDLE_WAIT_LOAD;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always_comb begin
        next_state = current_state;
        start_mmu = 0; // Default to 0

        case (current_state)
            IDLE_WAIT_LOAD: begin
                // Only transition to CALCULATING_START when both matrices are fully loaded
                if (&a_loaded && &b_loaded) begin
                    next_state = CALCULATING_START;
                end
                // Otherwise, stay here and continue loading
            end
            CALCULATING_START: begin
                start_mmu = 1; // Assert start_mmu for one cycle
                next_state = WAITING_FOR_MMU_DONE; // Immediately move to wait state
            end
            WAITING_FOR_MMU_DONE: begin
                if (done) begin // If mmu signals done
                    next_state = IDLE_WAIT_LOAD; // Go back to idle to allow new loads
                end
                // Otherwise, stay here and wait
            end
        endcase

        // Default C output
        out_data = (output_en) ? C[output_sel / 2][output_sel % 2] : 8'b0;
    end

    // Loading and Reset Logic (remains in always_ff)
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            a_loaded <= 0;
            b_loaded <= 0;
            foreach (A[i,j]) A[i][j] <= 0;
            foreach (B[i,j]) B[i][j] <= 0;
        end else begin
            // Load matrices only when in IDLE_WAIT_LOAD state or when not waiting for mmu
            // (Assuming load_en_in is driven by ui_in[0] from tt_um_tpu)
            if (load_en_in && current_state == IDLE_WAIT_LOAD) begin
                if (!load_sel_ab) begin
                    A[load_index / 2][load_index % 2] <= in_data;
                    a_loaded[load_index] <= 1;
                end else begin
                    B[load_index / 2][load_index % 2] <= in_data;
                    b_loaded[load_index] <= 1;
                end
            end
            
            // Clear 'loaded' flags AFTER the mmu signals 'done'
            if (done) begin
                a_loaded <= 0;
                b_loaded <= 0;
            end
        end
    end
endmodule