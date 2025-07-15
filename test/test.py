import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge
import numpy as np

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
    for i in range(4):
        dut.ui_in.value = matrix[i]
        dut.uio_in.value = (sel << 1) | (i << 2) | 1  # load_en=1, load_sel_ab=sel, load_index
        await RisingEdge(dut.clk)
        dut.uio_in.value = 0
        await RisingEdge(dut.clk)

async def read_output(dut):
    results = []
    for i in range(4):
        dut.uio_in.value = (i << 5) | (1 << 4)  # output_sel = i, output_en = 1
        await ClockCycles(dut.clk, 1)
        val = dut.uo_out.value.integer
        results.append(val)
        dut._log.info(f"Read C[{i//2}][{i%2}] = {val}")
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
    # A = [[1, 2],
    #      [3, 4]]
    A = [1, 2, 3, 4]  # row-major

    # ------------------------------
    # STEP 2: Load matrix B
    # B = [[5, 6],
    #      [7, 8]]
    B = [5, 6, 7, 8]  # row-major: [B00, B01, B10, B11]
    
    await load_matrix(dut, A, sel=0)
    await load_matrix(dut, B, sel=1)

    # ------------------------------
    # STEP 4: Read outputs
    expected = [19, 22, 43, 50]
    results = []

    await ClockCycles(dut.clk, 1)  # Wait for systolic array to compute
    
    results = await read_output(dut)

    # ------------------------------
    # STEP 5: Check results
    for i in range(4):
        assert results[i] == expected[i], f"C[{i//2}][{i%2}] = {results[i]} != expected {expected[i]}"

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
    B = [9, 10, 11, 12]  # row-major: [B00, B01, B10, B11]

    await load_matrix(dut, A, sel=0)
    await load_matrix(dut, B, sel=1)

    # ------------------------------
    # STEP 4: Read outputs
    expected = [111, 122, 151, 166]
    results = []

    await ClockCycles(dut.clk, 1)  # Wait for systolic array to compute
    
    results = await read_output(dut)

    # ------------------------------
    # STEP 5: Check results
    for i in range(4):
        assert results[i] == expected[i], f"C[{i//2}][{i%2}] = {results[i]} != expected {expected[i]}"

    dut._log.info("Test 2 passed!")