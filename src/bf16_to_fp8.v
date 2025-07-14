module bf16_to_fp8 (
    input  wire [15:0] in_bf16,
    output reg  [7:0]  out_fp8
);
    wire sign_bf16 = in_bf16[15];
    wire [7:0] exp_bf16 = in_bf16[14:7];
    wire [6:0] mant_bf16 = in_bf16[6:0];

    reg [3:0] exp_fp8;
    reg [2:0] mant_fp8;
    reg guard_bit, round_bit, sticky_bit;

    wire [7:0] target_fp8_biased_exp;  // Line 36 fix: Declared as wire
    assign target_fp8_biased_exp = exp_bf16 - 8'd120;  // Continuous assignment

    always @(*) begin
        // Default assignments
        exp_fp8 = 4'b0;
        mant_fp8 = 3'b0;
        guard_bit = 1'b0;
        round_bit = 1'b0;
        sticky_bit = 1'b0;

        if (target_fp8_biased_exp >= 0) begin
            exp_fp8 = target_fp8_biased_exp[3:0];
            mant_fp8 = mant_bf16[6:4];      // Line 45 fix
            guard_bit = mant_bf16[3];       // Line 46 fix
            round_bit = mant_bf16[2];       // Line 47 fix
            sticky_bit = |mant_bf16[1:0];   // Line 48 fix
        end
        out_fp8 = {sign_bf16, exp_fp8, mant_fp8};
    end
endmodule