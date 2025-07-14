// FP8 arithmetic processing element (with accumulation register)
module FP8_PE (
    input wire clk,
    input wire rst,
    input wire clear,

    input wire [7:0] a_in, // assumed FP8, E4M3
    input wire [7:0] b_in, // fp8 e4m3

    output reg [7:0] a_out,
    output reg [7:0] b_out,

    output reg [15:0] c_out
);

    wire sign_a = a_in[7];
    wire [3:0] exp_a = a_in[6:3];
    wire [2:0] mant_a = a_in[2:0];

    wire sign_b = b_in[7];
    wire [3:0] exp_b = b_in[6:3];
    wire [2:0] mant_b = b_in[2:0];

    // Restore implicit leading 1 and align mantissas to 8-bit
    wire [7:0] val_a = (exp_a == 0) ? {1'b0, mant_a, 4'b0000} : {1'b1, mant_a, 4'b0000};
    wire [7:0] val_b = (exp_b == 0) ? {1'b0, mant_b, 4'b0000} : {1'b1, mant_b, 4'b0000};

    // Calculate unbiased exponent (bias = 7)
    wire signed [5:0] scale_a = $signed({1'b0, exp_a}) - 6'd7;
    wire signed [5:0] scale_b = $signed({1'b0, exp_b}) - 6'd7;
    wire signed [5:0] total_scale = scale_a + scale_b;

    // Unsigned product
    wire [15:0] raw_product = val_a * val_b;

    // Scale using shift (manual handling of sign and direction)
    reg signed [31:0] scaled_long;
    always @(*) begin
        if (total_scale >= 0)
            scaled_long = $signed({16'd0, raw_product}) <<< total_scale;
        else
            scaled_long = $signed({16'd0, raw_product}) >>> -total_scale;
    end

    // Clip and apply sign
    wire result_sign = sign_a ^ sign_b;
    
    // effective rounding
    wire guard = scaled_long[6];
    wire round = scaled_long[5];
    wire sticky = |scaled_long[4:0];
    wire rounding = guard & (round | sticky); // IEEE 754 tie-break
    wire signed [15:0] scaled_clipped = scaled_long[22:7] + rounding; // 16-bit range
    wire signed [15:0] final_product = result_sign ? -scaled_clipped : scaled_clipped;

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