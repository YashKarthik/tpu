module controller (
    input  wire        clk,
    input  wire        load_en,
    input  wire        load_sel_ab,
    input  wire [1:0]  load_index,
    input  wire [7:0]  in_data,

    output logic [7:0] a_matrix [0:3],
    output logic [7:0] b_matrix [0:3],

    input  wire        output_en,
    input  wire [1:0]  output_sel,
    input  wire [7:0]  c_matrix [0:3],
    output wire [7:0]  out_data,

    output wire        done
);

    logic start;
    logic started;
    logic [3:0] a_loaded, b_loaded;

    mmu array_inst (
        .clk(clk),
        .rst(start),
        .A(a_matrix),
        .B(b_matrix),
        .C(c_matrix),
        .done(done)
    );

    always_ff @ (posedge clk) begin
        if (load_en) begin
            if(!load_sel_ab) begin
                a_matrix[load_index] <= in_data;
                a_loaded[load_index] <= 1;
            end else begin
                b_matrix[load_index] <= in_data;
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
