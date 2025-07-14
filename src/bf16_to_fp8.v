module bf16_to_fp8 (
    input  wire [15:0] in_bf16,
    output reg  [7:0]  out_fp8
);
    reg sign;
    reg [7:0] exp_bf16;
    reg [6:0] mant_bf16;
    reg [3:0] exp_fp8;
    reg [2:0] mant_fp8;
    reg guard, round, sticky;
    reg [9:0] mant_full;
    reg [4:0] exp_unbiased;
    reg overflow;

    always @(*) begin
        sign = in_bf16[15];
        exp_bf16 = in_bf16[14:7];
        mant_bf16 = in_bf16[6:0];

        if (exp_bf16 == 8'b0 && mant_bf16 == 0) begin
            // Zero
            out_fp8 = {sign, 7'b0};
        end
        else if (exp_bf16 == 8'hFF) begin
            // Inf or NaN in BF16
            if (mant_bf16 == 0)
                out_fp8 = {sign, 4'b1111, 3'b000}; // Inf
            else
                out_fp8 = {sign, 4'b1111, 3'b001}; // Quiet NaN
        end
        else begin
            // Normalized or subnormal BF16
            exp_unbiased = exp_bf16 - 8'd127;

            if ($signed(exp_unbiased) < -6) begin
                // Too small → subnormal FP8 or zero
                out_fp8 = {sign, 7'b0};
            end
            else begin
                // Candidate FP8 exponent
                exp_fp8 = exp_unbiased + 4'd8;
                overflow = (exp_fp8 >= 4'd15);

                if (overflow) begin
                    // Overflow → Inf
                    out_fp8 = {sign, 4'b1111, 3'b000};
                end
                else begin
                    // Normal FP8 encode
                    // Reconstruct full mantissa: implicit 1 + 7 bits + 3 rounding bits
                    mant_full = {1'b1, mant_bf16, 2'b00}; // 10 bits total

                    mant_fp8 = mant_full[9:7];      // Top 3 bits
                    guard     = mant_full[6];
                    round     = mant_full[5];
                    sticky    = |mant_full[4:0];

                    // Round to nearest-even
                    if (guard && (round || sticky || mant_fp8[0])) begin
                        mant_fp8 = mant_fp8 + 1;
                        if (mant_fp8 == 3'b000) begin
                            // Mantissa overflow → bump exponent
                            exp_fp8 = exp_fp8 + 1;
                            if (exp_fp8 == 4'd15)
                                out_fp8 = {sign, 4'b1111, 3'b000}; // Overflow to Inf
                            else
                                out_fp8 = {sign, exp_fp8, mant_fp8};
                        end
                        else begin
                            out_fp8 = {sign, exp_fp8, mant_fp8};
                        end
                    end
                    else begin
                        out_fp8 = {sign, exp_fp8, mant_fp8};
                    end
                end
            end
        end
    end
endmodule