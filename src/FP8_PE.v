// FP8 arithmetic processing element (with bf16 accumulation register)
module FP8_PE (
    input wire clk,
    input wire rst,
    input wire clear,

    input wire [7:0] a_in, // assumed FP8, E4M3
    input wire [7:0] b_in, // fp8 e4m3

    output reg [7:0] a_out,
    output reg [7:0] b_out,

    output reg [15:0] c_out // bf16 accumualtion, converted to fp8 in only 1 hardware unit @ higher level modules
);

    wire        sign_a = a_in[7];
    wire [3:0]  exp_a  = a_in[6:3];
    wire [2:0]  mant_a = a_in[2:0];

    wire        sign_b = b_in[7];
    wire [3:0]  exp_b  = b_in[6:3];
    wire [2:0]  mant_b = b_in[2:0];

    wire [7:0] val_a = (exp_a == 0) ? {4'b0000, mant_a} : {1'b1, mant_a, 4'b000}; // align to 8-bit scale
    wire [7:0] val_b = (exp_b == 0) ? {4'b0000, mant_b} : {1'b1, mant_b, 4'b000};

    wire signed [5:0] scale_a = $signed(exp_a) - 6'd7;
    wire signed [5:0] scale_b = $signed(exp_b) - 6'd7;
    wire signed [5:0] total_scale = scale_a + scale_b;

    wire [15:0] raw_product = val_a * val_b;

    wire signed [31:0] scaled_product_long = $signed(raw_product) <<< total_scale;
    wire signed [15:0] scaled_product = scaled_product_long[22:7]; // clip to 16 bits

    wire result_sign = sign_a ^ sign_b;
    wire signed [15:0] final_product = result_sign ? -scaled_product : scaled_product;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            c_out <= 16'd0;
            a_out <= 8'd0;
            b_out <= 8'd0;
            c_out <= 16'd0;
        end else if (clear) begin
            c_out <= 16'd0;
            a_out <= 8'd0;
            b_out <= 8'd0;
            c_out <= 16'd0;
        end else begin
            a_out <= a_in;
            b_out <= b_in;
            c_out <= c_out + final_product;
        end
    end

endmodule