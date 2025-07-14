// FP8 arithmetic processing element (with BF16 accumulation register)
module FP8_PE (
    input wire clk,
    input wire rst,
    input wire clear,

    input wire [7:0] a_in, // assumed FP8, E4M3
    input wire [7:0] b_in, // fp8 e4m3

    output reg [7:0] a_out,
    output reg [7:0] b_out,

    output reg [15:0] c_out // Now holds a Bfloat16 value
);

    // --- Part 1: FP8 Multiplication ---
    
    // Unpack FP8 inputs (E4M3: 1-bit sign, 4-bit exponent, 3-bit mantissa)
    wire sign_a = a_in[7];
    wire [3:0] exp_a = a_in[6:3];
    wire [2:0] mant_a = a_in[2:0];

    wire sign_b = b_in[7];
    wire [3:0] exp_b = b_in[6:3];
    wire [2:0] mant_b = b_in[2:0];

    // Restore implicit leading 1 and align mantissas for multiplication
    wire [7:0] val_a = (exp_a == 0) ? {1'b0, mant_a, 4'b0000} : {1'b1, mant_a, 4'b0000};
    wire [7:0] val_b = (exp_b == 0) ? {1'b0, mant_b, 4'b0000} : {1'b1, mant_b, 4'b0000};

    // Calculate unbiased exponent (bias = 7)
    wire signed [5:0] scale_a = $signed({1'b0, exp_a}) - 6'd7;
    wire signed [5:0] scale_b = $signed({1'b0, exp_b}) - 6'd7;
    wire signed [6:0] total_scale = scale_a + scale_b; // now 7-bit to prevent overflow

    // Unsigned product
    wire [15:0] raw_product_unsigned = val_a * val_b;
    wire result_sign = sign_a ^ sign_b;
    
    // --- Part 2: Convert Product to Bfloat16 (BF16: 1-bit sign, 8-bit exponent, 7-bit mantissa) ---

    // Find the position of the MSB for normalization (and new exponent)
    reg [3:0] leading_one_pos;
    wire [15:0] raw_product_norm_unsigned;
    reg [3:0] exp_shift;
    
    // Conceptual logic to normalize the product. This is a simplified version.
    // Use a priority encoder to find the most significant bit (MSB)
    always @(*) begin
        if (raw_product_unsigned[15]) begin
            leading_one_pos = 4'd15;
            exp_shift = 4'd0;
        end else if (raw_product_unsigned[14]) begin
            leading_one_pos = 4'd14;
            exp_shift = 4'd1;
        end else if (raw_product_unsigned[13]) begin
            leading_one_pos = 4'd13;
            exp_shift = 4'd2;
        end else if (raw_product_unsigned[12]) begin
            leading_one_pos = 4'd12;
            exp_shift = 4'd3;
        end else if (raw_product_unsigned[11]) begin
            leading_one_pos = 4'd11;
            exp_shift = 4'd4;
        end else if (raw_product_unsigned[10]) begin
            leading_one_pos = 4'd10;
            exp_shift = 4'd5;
        end else if (raw_product_unsigned[9]) begin
            leading_one_pos = 4'd9;
            exp_shift = 4'd6;
        end else if (raw_product_unsigned[8]) begin
            leading_one_pos = 4'd8;
            exp_shift = 4'd7;
        end else if (raw_product_unsigned[7]) begin
            leading_one_pos = 4'd7;
            exp_shift = 4'd8;
        end else if (raw_product_unsigned[6]) begin
            leading_one_pos = 4'd6;
            exp_shift = 4'd9;
        end else if (raw_product_unsigned[5]) begin
            leading_one_pos = 4'd5;
            exp_shift = 4'd10;
        end else if (raw_product_unsigned[4]) begin
            leading_one_pos = 4'd4;
            exp_shift = 4'd11;
        end else if (raw_product_unsigned[3]) begin
            leading_one_pos = 4'd3;
            exp_shift = 4'd12;
        end else if (raw_product_unsigned[2]) begin
            leading_one_pos = 4'd2;
            exp_shift = 4'd13;
        end else if (raw_product_unsigned[1]) begin
            leading_one_pos = 4'd1;
            exp_shift = 4'd14;
        end else if (raw_product_unsigned[0]) begin
            leading_one_pos = 4'd0;
            exp_shift = 4'd15;
        end else begin
            // Case for a zero product
            leading_one_pos = 4'd0;
            exp_shift = 4'd0;
        end
    end
    
    assign raw_product_norm_unsigned = raw_product_unsigned << exp_shift;
    
    // Calculate final exponent and mantissa for BF16 format
    wire signed [7:0] bf16_exp_unbiased = total_scale + leading_one_pos - 15;
    wire [7:0] bf16_exp = bf16_exp_unbiased + 8'd127; // BF16 bias is 127
    
    wire [8:0] bf16_mant_round = {raw_product_norm_unsigned[14:8], raw_product_norm_unsigned[7]}; // Mantissa + Guard
    wire [7:0] bf16_mantissa_rounded = (bf16_mant_round[0] == 1'b1) ? bf16_mant_round[8:1] + 1'b1 : bf16_mant_round[8:1];
    
    wire [15:0] final_product_bf16 = {result_sign, bf16_exp, bf16_mantissa_rounded[6:0]};

    // --- Part 3: BF16 Floating-Point Adder (for the accumulation) ---
    
    // Unpack accumulator and new product
    wire acc_sign = c_out[15];
    wire [7:0] acc_exp = c_out[14:7];
    wire [6:0] acc_mant = c_out[6:0];

    wire product_sign = final_product_bf16[15];
    wire [7:0] product_exp = final_product_bf16[14:7];
    wire [6:0] product_mant = final_product_bf16[6:0];

    // Determine larger exponent and shift mantissas for alignment
    wire [7:0] larger_exp = (acc_exp > product_exp) ? acc_exp : product_exp;
    wire [4:0] exp_diff = (acc_exp > product_exp) ? acc_exp - product_exp : product_exp - acc_exp;

    wire [8:0] acc_mant_ext = {1'b1, acc_mant, 1'b0}; // Add implicit 1 and extra bit for alignment
    wire [8:0] product_mant_ext = {1'b1, product_mant, 1'b0};

    wire [8:0] aligned_mant_a = (acc_exp > product_exp) ? acc_mant_ext : product_mant_ext >>> exp_diff;
    wire [8:0] aligned_mant_b = (acc_exp > product_exp) ? product_mant_ext >>> exp_diff : acc_mant_ext;

    // Perform mantissa addition
    wire [9:0] mant_sum = aligned_mant_a + aligned_mant_b;

    // Normalize result (simplified, no special cases)
    wire new_sign = (acc_sign == product_sign) ? acc_sign : mant_sum[9] ^ 1'b0; // This is a gross simplification
    wire [7:0] new_exp = larger_exp;
    wire [6:0] new_mant = mant_sum[8:2]; // Simplified mantissa extraction

    wire [15:0] next_c_out = {new_sign, new_exp, new_mant};

    // --- Part 4: Sequential Logic (now with BF16 accumulator) ---

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            c_out <= 16'd0; // All zeros represents BF16 zero
            a_out <= 8'd0;
            b_out <= 8'd0;
        end else if (clear) begin
            c_out <= 16'd0;
            a_out <= a_in;
            b_out <= b_in;
        end else begin
            a_out <= a_in;
            b_out <= b_in;
            c_out <= next_c_out;
        end
    end

endmodule