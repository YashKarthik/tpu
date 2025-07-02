module controller (
    input  logic         clk,
    input  logic         rst,
    input  logic         load_en_in,
    input  logic         load_sel_ab,
    input  logic [1:0]   load_index,
    input  logic [7:0]   in_data,
    input  logic         output_en,
    input  logic [1:0]   output_sel,
    output logic [7:0]   out_data,
    output logic         done
);

    typedef logic [7:0] matrix2x2_t [2][2];

    matrix2x2_t A, B, C;
    logic [3:0] a_loaded, b_loaded;
    logic       start_mmu;

    typedef enum logic [1:0] {
        IDLE_WAIT_LOAD,
        CALCULATING_START,
        WAITING_FOR_MMU_DONE
    } controller_state_t;

    controller_state_t current_state, next_state;

    systolic2x2 systolic_array (
        .clk(clk),
        .rst(rst),
        .start(start_mmu),
        .A(A),
        .B(B),
        .C(C),
        .done(done)
    );

    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            current_state <= IDLE_WAIT_LOAD;
        else
            current_state <= next_state;
    end

    always_comb begin
        next_state = current_state;
        start_mmu = 0;

        case (current_state)
            IDLE_WAIT_LOAD: begin
                if (&a_loaded && &b_loaded)
                    next_state = CALCULATING_START;
            end
            CALCULATING_START: begin
                start_mmu = 1;
                next_state = WAITING_FOR_MMU_DONE;
            end
            WAITING_FOR_MMU_DONE: begin
                if (done)
                    next_state = IDLE_WAIT_LOAD;
            end
        endcase

        out_data = (output_en) ? C[output_sel[1]][output_sel[0]] : 8'd0;
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            a_loaded <= 0;
            b_loaded <= 0;
            foreach (A[i,j]) A[i][j] <= 0;
            foreach (B[i,j]) B[i][j] <= 0;
        end else begin
            if (load_en_in && current_state == IDLE_WAIT_LOAD) begin
                if (!load_sel_ab) begin
                    A[load_index[1]][load_index[0]] <= in_data;
                    a_loaded[load_index] <= 1;
                end else begin
                    B[load_index[1]][load_index[0]] <= in_data;
                    b_loaded[load_index] <= 1;
                end
            end
            if (done) begin
                a_loaded <= 0;
                b_loaded <= 0;
            end
        end
    end

endmodule
