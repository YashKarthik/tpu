module controller (
    input  wire        clk,
    input  wire        rst,

    input  wire        load_en,
    input  wire        load_sel_ab,
    input  wire [1:0]  load_index,
    input  wire [7:0]  in_data,

    input  wire        output_en,
    input  wire        load_mem,
    input  wire [1:0]  mem_addr,
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
    reg [7:0] a_data0, b_data0, a_data1, b_data1;

    // Outputs from systolic array
    wire [15:0] c00, c01, c10, c11;

    // FSM state
    typedef enum logic [1:0] {
        IDLE,
        FEED,
        OUTPUT
    } state_t;

    // Output and cycle counters
    reg [2:0] cycle_count;
    reg [2:0] output_count;

    state_t state, next_state;

    wire clear = (output_count == 3);

    systolic_array_2x2 mmu (
        .clk(clk),
        .rst(rst),
        .clear(clear),
        .a_data0(a_data0),
        .a_data1(a_data1),
        .b_data0(b_data0),
        .b_data1(b_data1),
        .c00(c00), .c01(c01), .c10(c10), .c11(c11)
    );

    reg[1:0] mem_ptr; // current memory write address, cycles through
    reg mem_write_en;
    reg [31:0] mem_write_data;
    wire [31:0] mem_read_data;

    matrix_memory #(.WIDTH(8), .GROUPS(4)) sram (
        .clk(clk),
        .rst(rst),
        .write_en(mem_write_en),
        .write_addr(mem_ptr),
        .data_in(mem_write_data),
        .read_en(load_mem),
        .read_addr(mem_addr),
        .data_out(mem_read_data)
    );

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            mem_ptr <= 0;
        end else if (state == OUTPUT && output_en && output_count == 3) begin
            mem_ptr <= mem_ptr + 1;
        end
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            a_loaded <= 0;
            b_loaded <= 0;
            cycle_count <= 0;
            output_count <= 0;
        end else if (load_mem) begin
            $display("Loading %d, %d, %d, %d from memory", mem_read_data[7:0], mem_read_data[15:8], mem_read_data[23:16], mem_read_data[31:24]);
            if (!load_sel_ab) begin
                A[0] <= mem_read_data[7:0];
                A[1] <= mem_read_data[15:8];
                A[2] <= mem_read_data[23:16];
                A[3] <= mem_read_data[31:24];
                a_loaded <= 4'b1111;
            end else begin
                B[0] <= mem_read_data[7:0];
                B[1] <= mem_read_data[15:8];
                B[2] <= mem_read_data[23:16];
                B[3] <= mem_read_data[31:24];
                b_loaded <= 4'b1111;
            end
        end else begin
            if (load_en && state == IDLE) begin
                output_count <= 0;
                if (!load_sel_ab) begin
                    A[load_index] <= in_data;
                    a_loaded[load_index] <= 1;
                end else begin
                    B[load_index] <= in_data;
                    b_loaded[load_index] <= 1;
                end
            end else if (state == FEED) begin
                cycle_count <= cycle_count + 1;
                if (cycle_count == 3) begin
                    output_count <= output_count + 1;
                end
            end else if (state == OUTPUT && output_en) begin
                output_count <= output_count + 1;
                if (output_count == 2) begin
                    a_loaded <= 4'b0;
                    b_loaded <= 4'b0;
                    cycle_count <= 0;
                end
            end
        end
    end

    // FSM transitions
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (&a_loaded && &b_loaded) begin
                    next_state = FEED;
                end
            end
            FEED: begin
                if (cycle_count == 3) begin
                    next_state = OUTPUT;
                end
            end
            OUTPUT: begin
                if (output_count == 3) begin
                    next_state = IDLE;
                end
            end
        endcase
    end

    // Done signal
    assign done = (cycle_count == 3 || state == OUTPUT);

    // Feeding logic
    always @(*) begin
        a_data0 = 0;
        a_data1 = 0;
        b_data0 = 0;
        b_data1 = 0;

        if (state == FEED) begin
            case (cycle_count)
                0: begin a_data0 = A[0]; a_data1 = 0;     b_data0 = B[0]; b_data1 = 0; end
                1: begin a_data0 = A[1]; a_data1 = A[2];  b_data0 = B[2]; b_data1 = B[1]; end
                2: begin a_data0 = 0;    a_data1 = A[3];  b_data0 = 0;    b_data1 = B[3]; end
                default: begin end
            endcase
        end
    end

    // Capture outputs
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            C[0] <= 0; C[1] <= 0; C[2] <= 0; C[3] <= 0;
        end else begin
            C[0] <= c00;
            C[1] <= c01;
            C[2] <= c10;
            C[3] <= c11;
        end
    end
 
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            mem_write_en <= 0;
            mem_write_data <= 0;
        end else begin
            if (output_count == 1) begin
                mem_write_en <= 1;
                mem_write_data <= {C[3][7:0], C[2][7:0], C[1][7:0], C[0][7:0]};
                $display("Writing values %d, %d", mem_write_data, mem_write_en);
            end
            else begin
                mem_write_en <= 0;
            end
        end
    end

    // Output MUX
    always @(*) begin
        out_data_r = 0;
        if (output_en) begin
            out_data_r = C[output_count][7:0];
        end
    end

endmodule
