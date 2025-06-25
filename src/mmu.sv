// Systolic Array Multiplication
// Has Processing Elements arranged in a grid
// Contains pipelined buffering & flowing to optimize memory bandwidth & throughput
module mmu (
    input  logic         clk,
    input  logic         rst,
    input  logic         start,
    input  logic [7:0]   A [2][2],
    input  logic [7:0]   B [2][2],
    output logic [7:0]   C [2][2],
    output logic         done
);

    // Wires for data flow between PEs (A-flow right, B-flow down, C-flow right-down)
    logic [7:0] a_data_row0_pe0_out; // from PE00 to PE01 input
    logic [7:0] a_data_row1_pe0_out; // from PE10 to PE11 input

    logic [7:0] b_data_col0_pe0_out; // from PE00 to PE10 input
    logic [7:0] b_data_col1_pe0_out; // from PE01 to PE11 input

    logic [16:0] c_partial_00_out; // PE00 to PE01 input
    logic [16:0] c_partial_10_out; // PE10 to PE11 input
    logic [16:0] c_partial_01_out; // PE01 to PE00_next_row input (conceptual)
    logic [16:0] c_partial_11_out; // PE11 to PE01_next_row input (conceptual)

    logic [16:0] c_result_00_internal; // From PE_00 for C[0][0]
    logic [16:0] c_result_01_internal; // From PE_01 for C[0][1]
    logic [16:0] c_result_10_internal; // From PE_10 for C[1][0]
    logic [16:0] c_result_11_internal; // From PE_11 for C[1][1]

    // Control FSM for feeding inputs and managing 'done'
    logic [2:0] state;
    logic start_pe_pulse;

    localparam S_IDLE = 3'd0;
    localparam S_FEED_A_B_0 = 3'd1; // Feed A[0][0], B[0][0], A[1][0] (staggered)
    localparam S_FEED_A_B_1 = 3'd2; // Feed A[0][1], B[1][0], B[1][1] (staggered)
    localparam S_COMPUTE_1 = 3'd3;  // Further computation cycles
    localparam S_COMPUTE_2 = 3'd4;
    localparam S_OUTPUT = 3'd5;

    // Registers to pipeline inputs into the array
    logic [7:0] a_in_pe00_reg, b_in_pe00_reg;
    logic [7:0] a_in_pe10_reg, b_in_pe01_reg; // The other starting inputs for column 1 / row 1

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= S_IDLE;
            done <= 0;
            start_pe_pulse <= 0;
            a_in_pe00_reg <= 0;
            b_in_pe00_reg <= 0;
            a_in_pe10_reg <= 0;
            b_in_pe01_reg <= 0;
        end else begin
            done <= 0; 
            start_pe_pulse <= 0;

            case (state)
                S_IDLE: begin
                    if (start) begin
                        state <= S_FEED_A_B_0;
                        start_pe_pulse <= 1; // Pulse PEs to clear accumulators
                    end
                end
                S_FEED_A_B_0: begin
                    // Cycle 0: Feed A[0][0], B[0][0] to PE00
                    // A[1][0] to PE10. B[0][1] to PE01. (These arrive a cycle later due to wiring)
                    a_in_pe00_reg <= A[0][0]; // For PE00
                    b_in_pe00_reg <= B[0][0]; // For PE00

                    a_in_pe10_reg <= A[1][0]; // For PE10 (input from the left)
                    b_in_pe01_reg <= B[0][1]; // For PE01 (input from the top)

                    state <= S_FEED_A_B_1;
                end
                S_FEED_A_B_1: begin
                    // Cycle 1: Feed A[0][1] to PE01, B[1][0] to PE10, B[1][1] to PE11
                    a_in_pe00_reg <= A[0][1]; // This A[0][1] will go to PE01.
                    b_in_pe00_reg <= B[1][0]; // This B[1][0] will go to PE10.
                    // The dummy inputs below ensure data flow continues
                    a_in_pe10_reg <= 0; // No more A[1][X] input from controller
                    b_in_pe01_reg <= B[1][1]; // This B[1][1] will go to PE11.

                    state <= S_COMPUTE_1; // Additional cycles for data to flow
                end
                S_COMPUTE_1: begin
                    // Wait for data to flow through the pipeline
                    // No new A/B inputs from outside the array
                    a_in_pe00_reg <= 0;
                    b_in_pe00_reg <= 0;
                    a_in_pe10_reg <= 0;
                    b_in_pe01_reg <= 0;

                    state <= S_COMPUTE_2;
                end
                S_COMPUTE_2: begin
                    // Final values should be stable now
                    state <= S_OUTPUT;
                end
                S_OUTPUT: begin
                    done <= 1; // Signal that results are ready
                    state <= S_IDLE;
                end
            endcase
        end
    end

    // Instantiate the 2x2 grid of PEs
    // PE_00: Computes C[0][0]
    pe_cell pe_00 (
        .clk(clk),
        .rst(rst),
        .start_pulse(start_pe_pulse),
        .a_in(a_in_pe00_reg), // A[0][0] then A[0][1]
        .b_in(b_in_pe00_reg), // B[0][0] then B[1][0]
        .c_in(17'b0),          // Initial C is 0
        .a_out(a_data_row0_pe0_out),
        .b_out(b_data_col0_pe0_out),
        .c_out(c_result_00_internal) // Final C[0][0] will accumulate here
    );

    // PE_01: Computes C[0][1]
    pe_cell pe_01 (
        .clk(clk),
        .rst(rst),
        .start_pulse(start_pe_pulse),
        .a_in(a_data_row0_pe0_out), // A[0][0] then A[0][1] from PE00
        .b_in(b_in_pe01_reg),      // B[0][1] then B[1][1]
        .c_in(17'b0),               // Initial C is 0
        .a_out(),                  // Not used for column 1's last PE
        .b_out(b_data_col1_pe0_out),
        .c_out(c_result_01_internal) // Final C[0][1]
    );

    // PE_10: Computes C[1][0]
    pe_cell pe_10 (
        .clk(clk),
        .rst(rst),
        .start_pulse(start_pe_pulse),
        .a_in(a_in_pe10_reg),      // A[1][0] then A[1][1]
        .b_in(b_data_col0_pe0_out), // B[0][0] then B[1][0] from PE00
        .c_in(17'b0),               // Initial C is 0
        .a_out(a_data_row1_pe0_out),
        .b_out(),                  // Not used for row 1's last PE
        .c_out(c_result_10_internal) // Final C[1][0]
    );

    // PE_11: Computes C[1][1]
    pe_cell pe_11 (
        .clk(clk),
        .rst(rst),
        .start_pulse(start_pe_pulse),
        .a_in(a_data_row1_pe0_out), // A[1][0] then A[1][1] from PE10
        .b_in(b_data_col1_pe0_out), // B[0][1] then B[1][1] from PE01
        .c_in(17'b0),               // Initial C is 0
        .a_out(),                  // Not used as this is the last PE
        .b_out(),                  // Not used as this is the last PE
        .c_out(c_result_11_internal) // Final C[1][1]
    );

    // Output saturation 
    assign C[0][0] = (c_result_00_internal > 8'hFF) ? 8'hFF : c_result_00_internal[7:0];
    assign C[0][1] = (c_result_01_internal > 8'hFF) ? 8'hFF : c_result_01_internal[7:0];
    assign C[1][0] = (c_result_10_internal > 8'hFF) ? 8'hFF : c_result_10_internal[7:0];
    assign C[1][1] = (c_result_11_internal > 8'hFF) ? 8'hFF : c_result_11_internal[7:0];

endmodule