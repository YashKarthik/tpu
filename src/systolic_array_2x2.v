module systolic_array_2x2 #(
    parameter WIDTH = 8
)(
    input wire clk,
    input wire rst,

    input wire [WIDTH-1:0] a_data,
    input wire [WIDTH-1:0] b_data,
    input wire [1:0] a_row_idx,  // 0 or 1
    input wire [1:0] b_col_idx,  // 0 or 1
    input wire valid_in,

    output wire [2*WIDTH-1:0] c00,
    output wire [2*WIDTH-1:0] c01,
    output wire [2*WIDTH-1:0] c10,
    output wire [2*WIDTH-1:0] c11
);

    // Internal signals between PEs
    wire [WIDTH-1:0] a_wire [0:1][0:2];
    wire [WIDTH-1:0] b_wire [0:2][0:1];
    wire             v_wire [0:2][0:2];
    wire [15:0] c_array [0:1][0:1];

    // Input loading at top-left
    assign a_wire[0][0] = (valid_in && a_row_idx == 0) ? a_data : 0;
    assign a_wire[1][0] = (valid_in && a_row_idx == 1) ? a_data : 0;
    assign b_wire[0][0] = (valid_in && b_col_idx == 0) ? b_data : 0;
    assign b_wire[0][1] = (valid_in && b_col_idx == 1) ? b_data : 0;

    assign v_wire[0][0] = valid_in;
    assign v_wire[0][1] = valid_in;
    assign v_wire[1][0] = valid_in;
    assign v_wire[1][1] = valid_in;

    genvar i, j;
    generate
        for (i = 0; i < 2; i = i + 1) begin : row
            for (j = 0; j < 2; j = j + 1) begin : col
                PE #(.WIDTH(8)) pe_inst (
                    .clk(clk),
                    .rst(rst),
                    .a_in(a_wire[i][j]),
                    .b_in(b_wire[j][i]),
                    .valid_in(v_wire[j][i]),
                    .a_out(a_wire[i][j+1]),
                    .b_out(b_wire[j+1][i]),
                    .valid_out(v_wire[j+1][i+1]),
                    .c_out(c_array[i][j])
                );
            end
        end
    endgenerate

    assign c00 = c_array[0][0];
    assign c01 = c_array[0][1];
    assign c10 = c_array[1][0];
    assign c11 = c_array[1][1];
endmodule
