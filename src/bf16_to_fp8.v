module bf16_to_fp8 (
    input  wire [15:0] in_bf16,
    output reg  [7:0]  out_fp8
);
    wire sign_bf16 = in_bf16[15];
    wire [7:0] exp_bf16 = in_bf16[14:7];
    wire [6:0] mant_bf16 = in_bf16[6:0];

    reg [3:0] exp_fp8;
    reg [2:0] mant_fp8;

    reg [9:0] bf16_mant_extended;

    reg signed [7:0] exp_unbiased_bf16;

    reg guard_bit, round_bit, sticky_bit;
    reg round_up_flag;

    wire [4:0] subnormal_shift_amount = (target_fp8_biased_exp <= 0) ? (1 - target_fp8_biased_exp) : 5'b0;
    reg [9:0] shifted_mantissa_for_subnormal;
    wire signed [7:0] target_fp8_biased_exp = exp_bf16 - 8'd120;

    always @(*) begin
        // Initialize all variables to avoid latches
        out_fp8 = {sign_bf16, 7'b0};

        if (exp_bf16 == 8'b0 && mant_bf16 == 7'b0) begin
            // Zero
            out_fp8 = {sign_bf16, 7'b0};
        end
        else if (exp_bf16 == 8'hFF) begin
            // Inf or NaN in BF16
            if (mant_bf16 == 7'b0)
                out_fp8 = {sign_bf16, 4'b1111, 3'b000}; // Inf
            else
                out_fp8 = {sign_bf16, 4'b1111, 3'b001}; // Quiet NaN
        end
        else begin
            // Normalized or subnormal BF16
            exp_unbiased_bf16 = exp_bf16 - 8'd127;

            bf16_mant_extended = {1'b1, mant_bf16, 2'b00};

            if (target_fp8_biased_exp < 8'd0) begin
                // Too small → subnormal FP8 or zero
                exp_fp8 = 4'b0000;
                
                if (subnormal_shift_amount >= 10) begin // If shift amount is too large, it's effectively zero
                    shifted_mantissa_for_subnormal = 10'b0;
                end else begin
                    // Shift the extended mantissa to the right for subnormal representation
                    shifted_mantissa_for_subnormal = bf16_mant_extended >> subnormal_shift_amount;
                end
                mant_fp8 = shifted_mantissa_for_subnormal[9:7]; // Top 3 bits become FP8 mantissa
                guard_bit  = shifted_mantissa_for_subnormal[6];
                round_bit  = shifted_mantissa_for_subnormal[5];
                sticky_bit = |shifted_mantissa_for_subnormal[4:0]; // OR of all remaining bits

                // rounding to nearest even
                round_up_flag = (guard_bit && (round_bit || sticky_bit || mant_fp8[0]));
                if (round_up_flag) begin
                    mant_fp8 = mant_fp8 + 1;
                end

                if (mant_fp8 == 3'b100) begin
                    exp_fp8 = 4'b0001; // Smallest normalized FP8 exponent
                    mant_fp8 = 3'b000; // Reset mantissa for normalized form
                end

                if (exp_fp8 == 4'b0000 && mant_fp8 == 3'b000) begin
                    out_fp8 = {sign_bf16, 7'b0}; // Final zero
                end else begin
                    out_fp8 = {sign_bf16, exp_fp8, mant_fp8};
                end
            end
            else begin
                // Overflow outside normalized fp8 range
                mant_fp8 = bf16_mant_extended[9:7]; 
                guard_bit  = bf16_mant_extended[6];
                round_bit  = bf16_mant_extended[5];
                sticky_bit = |bf16_mant_extended[4:0];

                round_up_flag = (guard_bit && (round_bit || sticky_bit || mant_fp8[0]));
                if (round_up_flag) begin
                    mant_fp8 = mant_fp8 + 1;
                end
                if (mant_fp8 == 3'b100) begin // If mantissa becomes 1.000 after increment
                    exp_fp8 = target_fp8_biased_exp[3:0] + 1; // Increment exponent
                    mant_fp8 = 3'b000; // Mantissa becomes 000
                end else begin
                    exp_fp8 = target_fp8_biased_exp[3:0]; // Use the calculated target exponent
                end

                if (exp_fp8 >= 4'b1111) begin // If exponent reaches 15 (0b1111) or higher due to increment
                    out_fp8 = {sign_bf16, 4'b1111, 3'b000}; // Overflow to Inf
                end else begin
                    out_fp8 = {sign_bf16, exp_fp8, mant_fp8};
                end
            end
        end
    end
endmodule