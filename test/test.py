import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge
import numpy as np
import struct

def fp8_to_float_e4m3(b):
    """
    Convert 8-bit FP8 E4M3 byte to Python float.
    """
    sign = (b >> 7) & 0x1
    exp = (b >> 3) & 0xF
    mant = b & 0x7
    if exp == 0:
        val = (mant / 8.0) * 2**(-6)  # Denormalized
    else:
        val = (1 + mant / 8.0) * 2**(exp - 7)
    return -val if sign else val

def float_to_fp8_e4m3(x):
    """
    Convert Python float to FP8 E4M3 byte.
    Approximate via float16 truncation and reformatting.
    """
    # Special handling
    if np.isnan(x): return 0x7F
    if np.isinf(x): return 0x7C if x > 0 else 0xFC
    if x == 0: return 0x00 if np.signbit(x) == 0 else 0x80

    # Convert to float16 first for simplicity
    x16 = np.float16(x)
    bits = np.frombuffer(x16.tobytes(), dtype=np.uint16)[0]
    sign = (bits >> 15) & 0x1
    exp = (bits >> 10) & 0x1F
    mant = (bits >> 7) & 0x7

    # Convert to E4M3 (bias = 7)
    fp8_sign = sign
    fp8_exp = max(0, min(0xF, exp - 15 + 7))  # float16 bias 15 → FP8 bias 7
    fp8_mant = mant & 0x7  # 3 bits

    return (fp8_sign << 7) | (fp8_exp << 3) | fp8_mant

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

    # ------------------------------
    # STEP 1: Load matrix A
    A = [1.1, 2, 3, 4]  # row-major

    # ------------------------------
    # STEP 2: Load matrix B
    B = [5, 6, 7, 8]

    await load_matrix(dut, A, sel=0)
    await load_matrix(dut, B, sel=1)

    # ------------------------------
    # STEP 4: Read outputs
    expected = get_expected_matmul(A, B)
    
    await ClockCycles(dut.clk, 3)  # Wait for systolic array to compute
    
    results = await read_output(dut)

    # ------------------------------
    # STEP 5: Check results
    for i in range(4):
        assert np.isclose(results[i], expected[i], atol=1e-2), \
            f"C[{i//2}][{i%2}] = {results[i]} != expected {expected[i]}"
    
    dut._log.info("Test 1 passed!")

    #######################################
    ##### TEST RUN 2 - CHECK CLEARING #####
    
    # ------------------------------
    # STEP 1: Load matrix A
    # A = [[5, 6],
    #      [7, 8]]
    A = [5, 6, 7, 8]  # row-major

    # ------------------------------
    # STEP 2: Load matrix B
    # B = [[9, 10],
    #      [11, 12]]
    B = [9, 8, 7, 6]  # row-major: [B00, B01, B10, B11]

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
        assert np.isclose(results[i], expected[i], atol=1e-2), \
            f"C[{i//2}][{i%2}] = {results[i]} != expected {expected[i]}"
        
    dut._log.info("Test 2 passed!")