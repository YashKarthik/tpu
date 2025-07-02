// Systolic Array Multiplication
// Has Processing Elements arranged in a grid
// Contains pipelined buffering & flowing to optimize memory bandwidth & throughput
module systolic2x2 (
    input  logic         clk,
    input  logic         rst,
    input  logic         start,
    input  logic [7:0]   A [2][2], // A[row][col]
    input  logic [7:0]   B [2][2], // B[row][col]
    output logic [7:0]   C [2][2],
    output logic         done
);

    // Internal registers
    logic [7:0] a_pipe [3][2]; // [row][col]
    logic [7:0] b_pipe [2][3]; // [row][col]
    logic [7:0] c_wire [2][2];

    always_ff @(posedge clk or posedge rst) begin 
        if (rst) begin
            done <= 0;
        end else if (start) begin
            a_pipe[0][0] <= A[0][0];
            a_pipe[0][1] <= A[0][1];
            a_pipe[1][0] <= A[1][0];
            a_pipe[1][1] <= A[1][1];
            
            b_pipe[0][0] <= B[0][0];
            b_pipe[0][1] <= B[0][1];
            b_pipe[1][0] <= B[1][0];
            b_pipe[1][1] <= B[1][1];
        end
    end

    // PE Grid Arrangement
    genvar r, c; // genvar in case we make it bigger (?)
    generate
        for (r = 0; r < 2; r++) begin : row
            for (c = 0; c < 2; c++) begin: col
                logic [7:0] c_prev;
                if (r == 0 || c == 0)
                    assign c_prev = 8'd0;
                else
                    assign c_prev = c_wire[r-1][c-1];

                PE pe_inst (
                    .clk(clk),
                    .rst(rst),
                    .a_in(a_pipe[r][c]), // automatic connection
                    .b_in(b_pipe[r][c]),
                    .c_in(c_prev),
                    .a_out(a_pipe[r+1][c]),
                    .b_out(b_pipe[r][c+1]),
                    .c_out(c_wire[r][c])
                );
            end
        end
    endgenerate

    logic [1:0] cycle; // count cycle number

    // Matrix multiplication flows naturally
    // No need to control the flow, we are just counting cycles
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            cycle <= 0;
            C[0][0] <= 0; C[0][1] <= 0;
            C[1][0] <= 0; C[1][1] <= 0;
        end else if (start) begin
            if (cycle == 3) begin
                C[0][0] <= c_wire[0][0];
                C[0][1] <= c_wire[0][1];
                C[1][0] <= c_wire[1][0];
                C[1][1] <= c_wire[1][1];
                done <= 1;
                cycle <= 0;
            end else begin
                cycle <= cycle + 1;
                done <= 0;
            end
        end
    end

endmodule