module controller (
    input  wire        clk,
    input  wire        rst,

    input  wire        load_en,
    input  wire        load_sel_ab,
    input  wire [1:0]  load_index,
    input  wire [7:0]  in_data,

    input  wire        output_en,
    input  wire [1:0]  output_sel,
    output wire [7:0]  out_data,
    output wire        done
);

    // Storage for A and B matrices
    reg [7:0] A [0:3];
    reg [7:0] B [0:3];
    reg [3:0] a_loaded, b_loaded;

    // Output registers
    reg [15:0] C [0:3];
    reg [7:0] out_data_r;
    assign out_data = out_data_r;

    // Control signals to systolic array
    reg [7:0] a_data, b_data;
    reg [1:0] a_row_idx, b_col_idx;
    reg valid_in;

    // Outputs from systolic array
    wire [15:0] c00, c01, c10, c11;

    systolic_array_2x2 mmu (
        .clk(clk),
        .rst(rst),
        .a_data(a_data),
        .b_data(b_data),
        .a_row_idx(a_row_idx),
        .b_col_idx(b_col_idx),
        .valid_in(valid_in),
        .c00(c00), .c01(c01), .c10(c10), .c11(c11)
    );

    // Done signal when all results are captured
    assign done = (state == OUTPUT && output_count == 4);

    // FSM state
    typedef enum logic [1:0] {
        IDLE,
        FEED,
        WAIT,
        OUTPUT
    } state_t;

    state_t state, next_state;

    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            state <= IDLE;
        else
            state <= next_state;
    end

    // Output counter
    reg [2:0] cycle_count;
    reg [2:0] output_count;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            a_loaded <= 0;
            b_loaded <= 0;
            cycle_count <= 0;
            output_count <= 0;
        end else begin
            if (load_en && state == IDLE) begin
                if (!load_sel_ab) begin
                    A[load_index] <= in_data;
                    a_loaded[load_index] <= 1;
                end else begin
                    B[load_index] <= in_data;
                    b_loaded[load_index] <= 1;
                end
            end else if (state == FEED && valid_in) begin
                cycle_count <= cycle_count + 1;
            end else if (state == OUTPUT && output_en) begin
                output_count <= output_count + 1;
            end
        end
    end

    // FSM transitions
    always_comb begin
        next_state = state;
        case (state)
            IDLE: begin
                if (&a_loaded && &b_loaded)
                    next_state = FEED;
            end
            FEED: begin
                if (cycle_count == 4)
                    next_state = WAIT;
            end
            WAIT: begin
                next_state = OUTPUT;
            end
            OUTPUT: begin
                if (output_count == 4)
                    next_state = IDLE;
            end
        endcase
    end

    // Feeding logic
    always_comb begin
        a_data = 0;
        b_data = 0;
        a_row_idx = 0;
        b_col_idx = 0;
        valid_in = 0;

        if (state == FEED) begin
            $display("Feeding stuff");
            valid_in = 1;
            case (cycle_count)
                0: begin a_data = A[0]; a_row_idx = 0; b_data = B[0]; b_col_idx = 0; end
                1: begin a_data = A[1]; a_row_idx = 0; b_data = B[2]; b_col_idx = 0; end
                2: begin a_data = A[0]; a_row_idx = 0; b_data = B[1]; b_col_idx = 1; end
                3: begin a_data = A[2]; a_row_idx = 1; b_data = B[0]; b_col_idx = 0; end
            endcase
        end
    end

    // Capture outputs after latency
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            C[0] <= 0; C[1] <= 0; C[2] <= 0; C[3] <= 0;
        end else if (state == WAIT) begin
            C[0] <= c00;
            C[1] <= c01;
            C[2] <= c10;
            C[3] <= c11;
        end
    end

    // Output MUX
    always @(*) begin
        out_data_r = 0;
        if (state == OUTPUT && output_en) begin
            out_data_r = C[output_sel][7:0];  // Lower 8 bits
        end
    end

endmodule
