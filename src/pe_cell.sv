// A single processing element
module pe_cell (
    input  logic         clk,
    input  logic         rst,
    input  logic         start_pulse, // A pulse to reset accumulator at the beginning of calc
    input  logic [7:0]   a_in,
    input  logic [7:0]   b_in,
    input  logic [16:0]  c_in,       // Accumulated C value from previous PE/initial 0

    output logic [7:0]   a_out,
    output logic [7:0]   b_out,
    output logic [16:0]  c_out       // Accumulated C value to next PE/final output
);

    // Registers to pipeline A and B inputs
    logic [7:0] a_reg;
    logic [7:0] b_reg;

    // Accumulator for the partial sums of C. Widened to 17 bits.
    logic [16:0] acc;

    // Intermediate product (8-bit * 8-bit = 16-bit)
    logic [15:0] product;

    assign product = a_reg * b_reg; // Combinational multiply

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            a_reg <= 0;
            b_reg <= 0;
            acc <= 0;
        end else begin
            // Pulse 'start_pulse' to clear the accumulator for a new multiplication.
            // This 'start_pulse' needs to be timed correctly for the first values.
            if (start_pulse) begin
                acc <= c_in; // Initialize with c_in (typically 0 or previous partial sum)
            end else begin
                // Accumulate the product and the incoming partial sum (c_in)
                acc <= c_in + product; 
            end

            // Pass A and B inputs to the next PE in the systolic array.
            // These should be registered to maintain pipelining.
            a_reg <= a_in;
            b_reg <= b_in;
        end
    end

    // Output the registered A and B for the next PE
    assign a_out = a_reg; // Or simply a_in if no internal delay is needed for routing
    assign b_out = b_reg; // Same as above

    // Output the accumulated C value for the next PE or as a final result
    assign c_out = acc;

endmodule