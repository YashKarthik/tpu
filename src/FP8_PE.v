// FP8 arithmetic processing element (with bf16 accumulation register)
module FP8_PE (
    input wire clk,
    input wire rst,
    input wire clear,

    input wire [7:0] a_in, // assumed FP8, E4M3
    input wire [7:0] b_in,

    output reg [7:0] a_out,
    output reg [7:0] b_out,

    output reg [7:0] c_out_fp8 // final output FP8 - conversion pre-done here???
);
    
    reg [15:0] acc_bf16;
    wire [15:0] a_val;
    wire [15:0] b_val;
    wire [15:0] scaled_product;

    function [15:0] fp8_to_bf16;
        input [7:0] in;
        reg sign;
        reg [3:0] exp;
        reg [2:0] mant;
        reg [7:0] shifted;
        reg [15:0] out;
        begin
            sign = in[7];
            exp = in[6:3];
            mant = in[2:0];

            if (exp == 0) begin
                out = 0; // denormal (0 exponent) is equivalent to zero
            end else begin
                // exponent bias = 7, shift mantissa to Bf16 compliance
                shifted = (8 | mant) << (exp - 7);
                out = sign ? -shifted : shifted;
            end
            fp8_to_bf16 = out;
        end
    endfunction

    function [7:0] bf16_to_fp8;
        input [15:0] in;
        reg sign;
        reg [7:0] absval;
        reg [3:0] exp;
        reg [2:0] mant;
        reg [3:0] shift_pos; // position of Most Significant 1 bit
        begin
            sign = in[15];

            absval = sign ? -in[14:7] : in[14:7];

            if (absval == 0) begin
                bf16_to_fp8 = 8'd0;
            end else begin
                integer i;

                shift_pos = 0;
                if (absval[7]) shift_pos = 7;
                else if (absval[6]) shift_pos = 6;
                else if (absval[5]) shift_pos = 5;
                else if (absval[4]) shift_pos = 4;
                else if (absval[3]) shift_pos = 3;
                else if (absval[2]) shift_pos = 2;
                else if (absval[1]) shift_pos = 1;
                else if (absval[0]) shift_pos = 0;

                // normalize
                exp = shift_pos + 4'd7; // bias = 7
                mant = absval >> (shift_pos - 3); // Get top 3 bits (rounded)
                bf16_to_fp8 = {sign, exp, mant};
            end
        end
    endfunction

    assign a_val = fp8_to_bf16(a_in);
    assign b_val = fp8_to_bf16(b_in);
    assign scaled_product = ($signed(a_val) * $signed(b_val)) >> 7;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            acc_bf16 <= 16'd0;
            a_out <= 8'd0;
            b_out <= 8'd0;
            c_out_fp8 <= 8'd0;
        end else if (clear) begin
            acc_bf16 <= 16'd0;
            a_out <= 8'd0;
            b_out <= 8'd0;
            c_out_fp8 <= 8'd0;
        end else begin
            // pass through to next PE
            a_out <= a_in;
            b_out <= b_in;
            $display("inputs: %d, %d, scaled product %d", a_in, b_in, scaled_product);
            // Accumulate the product using signed addition
            acc_bf16 <= $signed(acc_bf16) + $signed(scaled_product);
            c_out_fp8 <= bf16_to_fp8(acc_bf16);
        end
    end

endmodule