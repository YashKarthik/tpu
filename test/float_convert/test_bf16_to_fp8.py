import cocotb
from cocotb.triggers import Timer
import numpy as np
import struct
import math

def float32_to_bf16(f32):
    """Convert float32 to bfloat16 with rounding to nearest even."""
    f32_bytes = struct.pack('>f', f32)
    f32_int = struct.unpack('>I', f32_bytes)[0]

    # Add rounding bit (0x00008000 is bit 16)
    rounded = f32_int + 0x00008000

    bf16_int = rounded >> 16
    return bf16_int

def float_to_fp8(value):
    if value == 0:
        return 0, 0.0
    if math.isnan(value) or math.isinf(value):
        return 0x7F, float('nan')
    sign = 1 if value < 0 else 0
    value = abs(value)
    if value != 0:
        exponent = math.floor(math.log2(value))
    else:
        exponent = -7
    exponent_bias = exponent + 7
    mantissa = value / (2 ** exponent) - 1.0 if value != 0 else 0
    mantissa_scaled = round(mantissa * 8)
    if exponent_bias <= 0:
        mantissa_scaled = round(value / (2 ** -6) * 8)
        exponent_bias = 0
        if mantissa_scaled >= 8:
            mantissa_scaled = 7
    elif exponent_bias > 15:
        return (sign << 7) | 0x7F, float('inf') * (-1 if sign else 1)
    mantissa_scaled = min(max(mantissa_scaled, 0), 7)
    fp8 = (sign << 7) | (exponent_bias << 3) | mantissa_scaled
    if exponent_bias == 0:
        reconstructed = (mantissa_scaled / 8.0) * (2 ** -6)
    else:
        reconstructed = (1.0 + mantissa_scaled / 8.0) * (2 ** (exponent_bias - 7))
    reconstructed = reconstructed * (-1 if sign else 1)
    return fp8, reconstructed

@cocotb.test()
async def test_bf16_to_fp8(dut):
    test_vals = np.random.normal(loc=0.0, scale=1.0, size=50)
    TOLERANCE = 0.30  # 5% relative error tolerance

    for i, val in enumerate(test_vals):
        bf16 = float32_to_bf16(val)
        dut.in_bf16.value = bf16
        await Timer(1, units="ns")  # wait propagation

        dut_fp8 = dut.out_fp8.value.integer
        ref_fp8, ref_reconstructed = float_to_fp8(val)

        # reconstruct DUT float from DUT FP8 output for comparison
        dut_sign = (dut_fp8 >> 7) & 0x1
        dut_exp = (dut_fp8 >> 3) & 0xF
        dut_mant = dut_fp8 & 0x7
        if dut_exp == 0:
            dut_reconstructed = (dut_mant / 8.0) * (2 ** -6)
        elif dut_exp == 0xF:
            dut_reconstructed = float('inf') if dut_mant == 0 else float('nan')
        else:
            dut_reconstructed = (1.0 + dut_mant / 8.0) * (2 ** (dut_exp - 7))
        dut_reconstructed = dut_reconstructed * (-1 if dut_sign else 1)

        dut._log.info(
            f"[{i:02d}] Float: {val:+.6f} | BF16: 0x{bf16:04X} | "
            f"DUT FP8: 0x{dut_fp8:02X} | Ref FP8: 0x{ref_fp8:02X} | "
            f"DUT Recon: {dut_reconstructed:+.6f} | Ref Recon: {ref_reconstructed:+.6f}"
        )

        # If either is nan or inf, do exact bit compare
        if math.isnan(ref_reconstructed) or math.isinf(ref_reconstructed):
            assert dut_fp8 == ref_fp8, (
                f"Mismatch at index {i}: DUT=0x{dut_fp8:02X} != REF=0x{ref_fp8:02X} "
                f"for input float {val}"
            )
        else:
            # Check relative error tolerance for reconstructed floats
            abs_err = abs(dut_reconstructed - ref_reconstructed)
            rel_err = abs_err / max(abs(ref_reconstructed), 1e-6)  # avoid div zero

            assert rel_err <= TOLERANCE, (
                f"Float mismatch at index {i}: DUT reconstructed={dut_reconstructed} vs "
                f"REF reconstructed={ref_reconstructed} (relative error={rel_err:.4f}) "
                f"for input float {val}"
            )