module systolic2x2 (
    input  wire        clk,
    input  wire        rst,
    input  wire        start,
    input  wire [7:0]  A00, A01, A10, A11,
    input  wire [7:0]  B00, B01, B10, B11,
    output reg  [7:0]  C00, C01, C10, C11,
    output reg         done
);

    // Input pipeline registers only for row 0 and col 0
    reg [7:0] a_pipe [0:1][0:1]; // only load into [0][*] and [1][*]
    reg [7:0] b_pipe [0:1][0:1]; // only load into [*][0] and [*][1]

    // Outputs from PEs
    wire [7:0] c_wire [0:1][0:1];
    wire [7:0] a_out  [0:1][0:1];
    wire [7:0] b_out  [0:1][0:1];

    reg [1:0] cycle;

    // Load inputs into top row and left column on start
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            cycle <= 0;
            done <= 0;
            C00 <= 0; C01 <= 0; C10 <= 0; C11 <= 0;

            a_pipe[0][0] <= 0; a_pipe[0][1] <= 0;
            a_pipe[1][0] <= 0; a_pipe[1][1] <= 0;
            b_pipe[0][0] <= 0; b_pipe[0][1] <= 0;
            b_pipe[1][0] <= 0; b_pipe[1][1] <= 0;

        end else begin
            if (start) begin
                a_pipe[0][0] <= A00;
                a_pipe[0][1] <= A01;
                a_pipe[1][0] <= A10;
                a_pipe[1][1] <= A11;

                b_pipe[0][0] <= B00;
                b_pipe[0][1] <= B01;
                b_pipe[1][0] <= B10;
                b_pipe[1][1] <= B11;

                cycle <= 0;
                done <= 0;
            end else begin
                cycle <= cycle + 1;
            end
            
            $display("Value of C00 is currently %d", c_wire[0][0]);

            if (cycle == 3) begin
                C00 <= c_wire[0][0];
                C01 <= c_wire[0][1];
                C10 <= c_wire[1][0];
                C11 <= c_wire[1][1];
                cycle <= 0;
            end else if (cycle == 4) begin
                done <= 1;
            end else begin
                done <= 0;
            end
        end
    end

    // Instantiate PEs and wire up internal forwarding
    genvar i, j;
    generate
        for (i = 0; i < 2; i = i + 1) begin : row
            for (j = 0; j < 2; j = j + 1) begin : col
                wire [7:0] a_in;
                wire [7:0] b_in;
                wire [7:0] c_in;

                if (i == 0) begin
                    assign a_in = a_pipe[i][j];
                end else begin
                    assign a_in = a_out[i-1][j];
                end

                if (j == 0) begin
                    assign b_in = b_pipe[i][j];
                end else begin
                    assign b_in = b_out[i][j-1];
                end

                if (i == 0 || j == 0) begin
                    assign c_in = 8'd0;
                end else begin
                    assign c_in = c_wire[i-1][j-1];
                end

                PE pe_inst (
                    .clk(clk),
                    .rst(rst),
                    .a_in(a_in),
                    .b_in(b_in),
                    .c_in(c_in),
                    .a_out(a_out[i][j]),
                    .b_out(b_out[i][j]),
                    .c_out(c_wire[i][j])
                );
            end
        end
    endgenerate

endmodule
