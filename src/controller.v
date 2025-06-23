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

    reg start;
    reg started;

    integer i;

    reg [3:0] a_loaded, b_loaded; // confirming loads of matrices for safe multiplication
    
    reg [31:0] A_flat, B_flat;
    wire [31:0] c_matrix_flat;

    wire [7:0] c_matrix [0:3];
    assign c_matrix[0] = c_matrix_flat[7:0];
    assign c_matrix[1] = c_matrix_flat[15:8];
    assign c_matrix[2] = c_matrix_flat[23:16];
    assign c_matrix[3] = c_matrix_flat[31:24];

    mmu array_inst (
        .clk(clk),
        .rst(~start),
        .A_flat(A_flat),
        .B_flat(B_flat),
        .C_flat(c_matrix_flat),
        .done(done)
    );

    always @ (posedge clk) begin
        if (rst) begin
            A_flat <= 32'b0;
            A_flat <= 32'b0;
            a_loaded <= 4'b0;
            b_loaded <= 4'b0;
            start <= 0;
            started <= 0;
        end else if (load_en) begin
            if(!load_sel_ab) begin
                A_flat[8*load_index +: 8] <= in_data;
                a_loaded[load_index] <= 1;
            end else begin
                B_flat[8*load_index +: 8] <= in_data;
                b_loaded[load_index] <= 1;
            end
        end

        // &x_loaded => if all elements of x are loaded
        if (&a_loaded && &b_loaded && !started) begin
            start <= 1;
            started <= 1;
        end else begin
            start <= 0;
        end
    end

    assign out_data = (output_en) ? c_matrix[output_sel] : 8'b0;
    
endmodule
