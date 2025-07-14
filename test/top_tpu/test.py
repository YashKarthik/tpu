import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge
import numpy as np

def fp8_to_float_e4m3(b):
    """
    Convert 8-bit FP8 E4M3 byte to Python float.
    """
    sign = (b >> 7) & 0x1
    exp  = (b >> 3) & 0xF
    mant = b & 0x7

    if exp == 0:
        # Subnormal: exp = -6, no implicit leading 1
        val = (mant / 8.0) * 2**(-6)
    elif exp == 0xF:
        if mant == 0:
            val = float('inf')
        else:
            val = float('nan')
    else:
        # Normalized
        val = (1 + mant / 8.0) * 2**(exp - 7)

    return -val if sign else val

def float_to_fp8_e4m3(value):
    """
    Convert a Python float to FP8 (E4M3 format: 1 sign bit, 4 exponent bits, 3 mantissa bits).
    Returns the FP8 value as an 8-bit integer and the reconstructed float value.
    """
    import math
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
    return fp8

def get_expected_matmul(A, B):
    """
    Args: lists A, B as flattened row-major matrices
    """
    return (np.array(A).reshape(2, 2) @ np.array(B).reshape(2, 2)).flatten().tolist()

async def load_matrix(dut, matrix, sel):
    """
    Load a 2x2 matrix into the DUT.
    
    Args:
        dut: Device Under Test
        matrix: list of 4 values (row-major)
        sel: 0 for matrix A, 1 for matrix B
    """
    matrix = [float_to_fp8_e4m3(x) for x in matrix]
    for i in range(4):
        dut.ui_in.value = int(matrix[i])
        dut.uio_in.value = (sel << 1) | (i << 2) | 1  # load_en=1, load_sel_ab=sel, load_index
        await RisingEdge(dut.clk)
        dut.uio_in.value = 0
        await RisingEdge(dut.clk)

async def read_output(dut):
    results = []
    for i in range(4):
        dut.uio_in.value = (i << 5) | (1 << 4)  # output_sel = i, output_en = 1
        await ClockCycles(dut.clk, 1)
        val_fp8 = dut.uo_out.value.integer
        val_float = fp8_to_float_e4m3(val_fp8)
        results.append(val_float)
        dut._log.info(f"Read C[{i//2}][{i%2}] = {val_float}")
        dut.uio_in.value = 0
        await ClockCycles(dut.clk, 1)
    return results

@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5)

    A = [1.1, 0.2, 3, 4]  # row-major

    B = [1.85, 2.1, 3.2, 1.7]

    await load_matrix(dut, A, sel=0)
    await load_matrix(dut, B, sel=1)

    # ------------------------------
    # STEP 4: Read outputs
    expected = get_expected_matmul(A, B)
    
    await ClockCycles(dut.clk, 3)  # Wait for systolic array to compute
    
    results = await read_output(dut)

    dut._log.info(expected)

    # ------------------------------
    # STEP 5: Check results
    for i in range(4):
        assert np.isclose(results[i], expected[i], rtol=0.20, atol=1.0), \
            f"C[{i//2}][{i%2}] = {results[i]} != expected {expected[i]}"
    
    dut._log.info("Test 1 passed!")

    #######################################
    ##### TEST RUN 2 - CHECK CLEARING #####
    
    # ------------------------------
    # STEP 1: Load matrix A
    # A = [[5, 6],
    #      [7, 8]]
    A = [1.6, 0.22, 1.2, 0.8]  # row-major

    # ------------------------------
    # STEP 2: Load matrix B
    # B = [[9, 10],
    #      [11, 12]]
    B = [1.1, 1.2, 0.8, 1.5]  # row-major: [B00, B01, B10, B11]

    await load_matrix(dut, A, sel=0)
    await load_matrix(dut, B, sel=1)

    # ------------------------------
    # STEP 4: Read outputs
    expected = get_expected_matmul(A, B)
    results = []

    await ClockCycles(dut.clk, 3)  # Wait for systolic array to compute
    
    results = await read_output(dut)

    # ------------------------------
    # STEP 5: Check results
    for i in range(4):
        assert np.isclose(results[i], expected[i], rtol=0.25, atol=1e-1), \
            f"C[{i//2}][{i%2}] = {results[i]} != expected {expected[i]}"
        
    dut._log.info("Test 2 passed!")