// FP8 arithmetic processing element (with BF16 accumulation register)
module FP8_PE (
    input wire clk,
    input wire rst,
    input wire clear,
    input wire [7:0] a_in, // FP8, E4M3
    input wire [7:0] b_in, // FP8, E4M3
    output reg [7:0] a_out,
    output reg [7:0] b_out,
    output reg [15:0] c_out // BF16 value
);

    // --- Part 1: FP8 Multiplication ---

    // Unpack FP8 inputs (E4M3: 1 sign bit, 4 exponent bits, 3 mantissa bits)
    wire sign_a = a_in[7];
    wire [3:0] exp_a = a_in[6:3];
    wire [2:0] mant_a = a_in[2:0];

    wire sign_b = b_in[7];
    wire [3:0] exp_b = b_in[6:3];
    wire [2:0] mant_b = b_in[2:0];

    // Result sign of the product
    wire result_sign = sign_a ^ sign_b;

    // Derived properties for FP8 A and B
    reg signed [5:0] unbiased_exp_a, unbiased_exp_b;
    reg [7:0] effective_mant_a, effective_mant_b;

    // Product calculation intermediates
    reg signed [6:0] product_unbiased_exp_raw;
    reg [15:0] product_mantissa_raw;

    // BF16 normalization and rounding signals
    reg [3:0] norm_shift_amount;
    reg signed [8:0] bf16_exp_unbiased;
    reg [15:0] bf16_mantissa_pre_norm;
    reg [6:0] bf16_mantissa_final;
    reg bf16_exp_inc_for_rounding;
    reg [7:0] bf16_exp_biased;
    reg [15:0] final_product_bf16_val;

    // FP8 Unpacking for A
    always @(*) begin
        if (exp_a == 4'b0000) begin
            if (mant_a == 3'b000) begin // Zero
                unbiased_exp_a = -6'd63;
                effective_mant_a = 8'b0;
            end else begin // Subnormal
                unbiased_exp_a = -6'd6;
                effective_mant_a = {1'b0, mant_a, 4'b0000};
            end
        end else if (exp_a == 4'b1111) begin // Inf or NaN
            unbiased_exp_a = 6'd63;
            effective_mant_a = (mant_a == 3'b000) ? 8'b0 : 8'b10000000;
        end else begin // Normalized
            unbiased_exp_a = $signed({1'b0, exp_a}) - 6'd7;
            effective_mant_a = {1'b1, mant_a, 4'b0000};
        end
    end

    // FP8 Unpacking for B
    always @(*) begin
        if (exp_b == 4'b0000) begin
            if (mant_b == 3'b000) begin // Zero
                unbiased_exp_b = -6'd63;
                effective_mant_b = 8'b0;
            end else begin // Subnormal
                unbiased_exp_b = -6'd6;
                effective_mant_b = {1'b0, mant_b, 4'b0000};
            end
        end else if (exp_b == 4'b1111) begin // Inf or NaN
            unbiased_exp_b = 6'd63;
            effective_mant_b = (mant_b == 3'b000) ? 8'b0 : 8'b10000000;
        end else begin // Normalized
            unbiased_exp_b = $signed({1'b0, exp_b}) - 6'd7;
            effective_mant_b = {1'b1, mant_b, 4'b0000};
        end
    end

    // Product Calculation
    always @(*) begin
        if (effective_mant_a == 0 || effective_mant_b == 0) begin
            product_unbiased_exp_raw = -6'd63;
            product_mantissa_raw = 16'b0;
        end else if (unbiased_exp_a == 6'd63 || unbiased_exp_b == 6'd63) begin
            if ((unbiased_exp_a == 6'd63 && effective_mant_a != 0) || 
                (unbiased_exp_b == 6'd63 && effective_mant_b != 0)) begin
                product_unbiased_exp_raw = 6'd63;
                product_mantissa_raw = 16'h8000; // NaN
            end else if ((unbiased_exp_a == 6'd63 && unbiased_exp_b == -6'd63) || 
                         (unbiased_exp_b == 6'd63 && unbiased_exp_a == -6'd63)) begin
                product_unbiased_exp_raw = 6'd63;
                product_mantissa_raw = 16'h8000; // NaN
            end else begin
                product_unbiased_exp_raw = 6'd63;
                product_mantissa_raw = 16'b0; // Inf
            end
        end else begin
            product_unbiased_exp_raw = unbiased_exp_a + unbiased_exp_b;
            product_mantissa_raw = effective_mant_a * effective_mant_b;
        end
    end

    // BF16 Normalization and Rounding
    always @(*) begin
        norm_shift_amount = 0;
        bf16_exp_unbiased = 0;
        bf16_mantissa_pre_norm = 0;
        bf16_mantissa_final = 7'b0;
        bf16_exp_inc_for_rounding = 0;
        bf16_exp_biased = 0;
        final_product_bf16_val = {result_sign, 15'b0};

        if (product_mantissa_raw == 0) begin
            final_product_bf16_val = {result_sign, 15'b0};
        end else if (product_unbiased_exp_raw == 6'd63) begin
            final_product_bf16_val = {result_sign, 8'hFF, (product_mantissa_raw == 0) ? 7'b0 : 7'h40};
        end else begin
            // Normalization
            if (product_mantissa_raw[15]) begin
                norm_shift_amount = 1;
                bf16_exp_unbiased = product_unbiased_exp_raw + 1;
                bf16_mantissa_pre_norm = product_mantissa_raw >> 1;
            end else begin
                if (product_mantissa_raw[14]) norm_shift_amount = 0;
                else if (product_mantissa_raw[13]) norm_shift_amount = 1;
                else if (product_mantissa_raw[12]) norm_shift_amount = 2;
                else if (product_mantissa_raw[11]) norm_shift_amount = 3;
                else if (product_mantissa_raw[10]) norm_shift_amount = 4;
                else if (product_mantissa_raw[9]) norm_shift_amount = 5;
                else if (product_mantissa_raw[8]) norm_shift_amount = 6;
                else if (product_mantissa_raw[7]) norm_shift_amount = 7;
                else if (product_mantissa_raw[6]) norm_shift_amount = 8;
                else if (product_mantissa_raw[5]) norm_shift_amount = 9;
                else if (product_mantissa_raw[4]) norm_shift_amount = 10;
                else if (product_mantissa_raw[3]) norm_shift_amount = 11;
                else if (product_mantissa_raw[2]) norm_shift_amount = 12;
                else if (product_mantissa_raw[1]) norm_shift_amount = 13;
                else norm_shift_amount = 14;
                bf16_exp_unbiased = product_unbiased_exp_raw - norm_shift_amount;
                bf16_mantissa_pre_norm = product_mantissa_raw << norm_shift_amount;
            end

            // Rounding (directly using bits)
            bf16_mantissa_final = bf16_mantissa_pre_norm[14:8];
            if (bf16_mantissa_pre_norm[7] && (bf16_mantissa_pre_norm[6] || |bf16_mantissa_pre_norm[5:0] || bf16_mantissa_final[0])) begin
                bf16_mantissa_final = bf16_mantissa_final + 1;
                if (bf16_mantissa_final == 0) begin
                    bf16_exp_inc_for_rounding = 1;
                end
            end

            // Final exponent
            bf16_exp_unbiased = bf16_exp_unbiased + bf16_exp_inc_for_rounding;
            if (bf16_exp_unbiased >= 128) begin
                bf16_exp_biased = 8'hFF;
                bf16_mantissa_final = 7'b0;
            end else if (bf16_exp_unbiased <= -127) begin
                bf16_exp_biased = 0;
                bf16_mantissa_final = 7'b0;
            end else begin
                bf16_exp_biased = bf16_exp_unbiased + 127;
            end

            final_product_bf16_val = {result_sign, bf16_exp_biased, bf16_mantissa_final};
        end
    end

    // --- Part 2: BF16 Floating-Point Adder ---

    // Unpack accumulator and product
    wire acc_sign = c_out[15];
    wire [7:0] acc_exp = c_out[14:7];
    wire [6:0] acc_mant = c_out[6:0];
    wire product_sign = final_product_bf16_val[15];
    wire [7:0] product_exp = final_product_bf16_val[14:7];
    wire [6:0] product_mant = final_product_bf16_val[6:0];

    // Special case detection
    wire acc_is_nan = (acc_exp == 8'hFF) && (acc_mant != 0);
    wire acc_is_inf = (acc_exp == 8'hFF) && (acc_mant == 0);
    wire acc_is_zero = (acc_exp == 0) && (acc_mant == 0);
    wire product_is_nan = (product_exp == 8'hFF) && (product_mant != 0);
    wire product_is_inf = (product_exp == 8'hFF) && (product_mant == 0);
    wire product_is_zero = (product_exp == 0) && (product_mant == 0);

    reg [15:0] next_c_out;

    // Helper regs for addition
    reg [7:0] exp_max;
    reg [7:0] exp_diff;
    reg [15:0] mant_a_ext;
    reg [15:0] mant_b_ext;
    reg [15:0] aligned_mant_a;
    reg [15:0] aligned_mant_b;
    reg signed [16:0] sum_mant_signed;
    reg add_result_sign; // Separate reg for addition result sign
    reg [15:0] abs_sum_mant;
    reg [4:0] shift_amount;
    reg [15:0] normalized_mant;
    reg [8:0] result_exp_temp;
    reg [6:0] result_mant;

    always @(*) begin
        // Default assignments to prevent latch inference
        exp_max = 0;
        exp_diff = 0;
        mant_a_ext = 0;
        mant_b_ext = 0;
        aligned_mant_a = 0;
        aligned_mant_b = 0;
        sum_mant_signed = 0;
        add_result_sign = 0;
        abs_sum_mant = 0;
        shift_amount = 0;
        normalized_mant = 0;
        result_exp_temp = 0;
        result_mant = 0;
        next_c_out = 0;

        if (acc_is_nan || product_is_nan) begin
            next_c_out = {1'b0, 8'hFF, 7'h40}; // NaN
        end else if (acc_is_inf) begin
            if (product_is_inf && (acc_sign != product_sign)) begin
                next_c_out = {1'b0, 8'hFF, 7'h40}; // NaN
            end else begin
                next_c_out = c_out; // Infinity
            end
        end else if (product_is_inf) begin
            next_c_out = final_product_bf16_val;
        end else if (acc_is_zero && product_is_zero) begin
            next_c_out = {acc_sign & product_sign, 15'b0};
        end else if (acc_is_zero) begin
            next_c_out = final_product_bf16_val;
        end else if (product_is_zero) begin
            next_c_out = c_out;
        end else begin
            // Normal addition
            exp_max = (acc_exp > product_exp) ? acc_exp : product_exp;
            exp_diff = exp_max - ((acc_exp < product_exp) ? acc_exp : product_exp);

            // Extend mantissas
            mant_a_ext = {1'b1, acc_mant, 7'b0};
            mant_b_ext = {1'b1, product_mant, 7'b0};

            // Align mantissas
            aligned_mant_a = (acc_exp >= product_exp) ? mant_a_ext : (exp_diff > 15 ? 0 : mant_a_ext >> exp_diff);
            aligned_mant_b = (product_exp >= acc_exp) ? mant_b_ext : (exp_diff > 15 ? 0 : mant_b_ext >> exp_diff);

            // Signed addition
            sum_mant_signed = (acc_sign ? -{1'b0, aligned_mant_a} : {1'b0, aligned_mant_a}) + 
                              (product_sign ? -{1'b0, aligned_mant_b} : {1'b0, aligned_mant_b});
            add_result_sign = sum_mant_signed < 0;
            abs_sum_mant = add_result_sign ? -sum_mant_signed[15:0] : sum_mant_signed[15:0];

            // Normalization with priority encoder
            if (abs_sum_mant[15]) shift_amount = 0;
            else if (abs_sum_mant[14]) shift_amount = 1;
            else if (abs_sum_mant[13]) shift_amount = 2;
            else if (abs_sum_mant[12]) shift_amount = 3;
            else if (abs_sum_mant[11]) shift_amount = 4;
            else if (abs_sum_mant[10]) shift_amount = 5;
            else if (abs_sum_mant[9]) shift_amount = 6;
            else if (abs_sum_mant[8]) shift_amount = 7;
            else if (abs_sum_mant[7]) shift_amount = 8;
            else if (abs_sum_mant[6]) shift_amount = 9;
            else if (abs_sum_mant[5]) shift_amount = 10;
            else if (abs_sum_mant[4]) shift_amount = 11;
            else if (abs_sum_mant[3]) shift_amount = 12;
            else if (abs_sum_mant[2]) shift_amount = 13;
            else if (abs_sum_mant[1]) shift_amount = 14;
            else shift_amount = 15;

            normalized_mant = abs_sum_mant << shift_amount;
            result_exp_temp = exp_max - shift_amount;
            result_mant = normalized_mant[14:8];

            // Final result
            if (sum_mant_signed == 0) begin
                next_c_out = {add_result_sign, 8'b0, 7'b0};
            end else if (result_exp_temp >= 255) begin
                next_c_out = {add_result_sign, 8'hFF, 7'b0};
            end else if (result_exp_temp <= 0) begin
                next_c_out = {add_result_sign, 8'b0, 7'b0};
            end else begin
                next_c_out = {add_result_sign, result_exp_temp[7:0], result_mant};
            end
        end
    end

    // --- Part 3: Sequential Logic ---
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            c_out <= 16'b0;
            a_out <= 8'b0;
            b_out <= 8'b0;
        end else if (clear) begin
            c_out <= 16'b0;
            a_out <= a_in;
            b_out <= b_in;
        end else begin
            a_out <= a_in;
            b_out <= b_in;
            c_out <= next_c_out;
        end
    end

endmodule