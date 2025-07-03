module controller (
    input  wire        clk,
    input  wire        rst,

    // Control and data inputs
    input  wire        load_en,
    input  wire        load_sel_ab,
    input  wire [1:0]  load_index,
    input  wire [7:0]  in_data,

    input  wire        output_en,
    input  wire [1:0]  output_sel,
    output wire [7:0]  out_data,

    output wire        done
);
    // Matrix element registers
    reg [7:0] A00, A01, A10, A11;
    reg [7:0] B00, B01, B10, B11;
    wire [7:0] C00, C01, C10, C11;
    wire mmu_done;

    reg start;
    reg [3:0] a_loaded, b_loaded;
    reg [7:0] out_data_r;
    reg [7:0] C_reg [0:3];
    assign out_data = out_data_r;

    // Instantiate systolic array
    systolic2x2 mmu (
        .clk(clk),
        .rst(rst),
        .start(start),
        .A00(A00), .A01(A01), .A10(A10), .A11(A11),
        .B00(B00), .B01(B01), .B10(B10), .B11(B11),
        .C00(C00), .C01(C01), .C10(C10), .C11(C11),
        .done(mmu_done)
    );

    assign done = mmu_done;

    // FSM states
    typedef enum logic [1:0] {
        IDLE,
        WAIT_START,
        COMPUTE,
        OUTPUT
    } state_t;

    state_t state, next_state;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
        
        $display("In state %d\n", state);
    end

    // FSM transitions
    always_comb begin
        next_state = state;
        start = 1'b1;

        case (state)
            IDLE: begin
                start = 1'b0;
                if (&a_loaded && &b_loaded)
                    next_state = WAIT_START;
            end
            WAIT_START: begin
                start = 1'b0;
                next_state = COMPUTE;
            end
            COMPUTE: begin
                if (mmu_done)
                    next_state = OUTPUT;
            end
            OUTPUT: begin
                if (!output_en) // wait for host to read all 4 outputs
                    next_state = IDLE;
            end
        endcase
    end

    // Data loading
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            A00 <= 0; A01 <= 0; A10 <= 0; A11 <= 0;
            B00 <= 0; B01 <= 0; B10 <= 0; B11 <= 0;
            a_loaded <= 0;
            b_loaded <= 0;
        end else if (load_en && state == IDLE) begin
            $display("Loading%d\n", in_data);
            if (!load_sel_ab) begin
                case (load_index)
                    2'd0: A00 <= in_data;
                    2'd1: A01 <= in_data;
                    2'd2: A10 <= in_data;
                    2'd3: A11 <= in_data;
                endcase
                a_loaded[load_index] <= 1;
            end else begin
                case (load_index)
                    2'd0: B00 <= in_data;
                    2'd1: B01 <= in_data;
                    2'd2: B10 <= in_data;
                    2'd3: B11 <= in_data;
                endcase
                b_loaded[load_index] <= 1;
            end
        end
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            C_reg[0] <= 0;
            C_reg[1] <= 0;
            C_reg[2] <= 0;
            C_reg[3] <= 0;
        end else if (mmu_done) begin
            C_reg[0] <= C00;
            C_reg[1] <= C01;
            C_reg[2] <= C10;
            C_reg[3] <= C11;
        end
    end

    always_comb begin
        out_data_r = 8'd0;
        if (output_en && state == OUTPUT) begin
            out_data_r = C_reg[output_sel];
        end
    end

endmodule
