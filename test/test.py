import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge
import numpy as np # pop in numpy for easy expected result checks

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

async def trigger_load_mem(dut, sel, addr):
    dut.uio_in.value = (1 << 7) | (sel << 1) | addr  # load_mem=1, sel, addr
    await RisingEdge(dut.clk)
    dut.uio_in.value = 0
    await RisingEdge(dut.clk)

@cocotb.test()
async def matmul_from_memory(dut):
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

    # Load 2 matrices
    A = [1, 2, 3, 4]  # row-major
    B = [5, 6, 7, 8]

    await load_matrix(dut, A, sel=0)
    await load_matrix(dut, B, sel=1)

    # Compute output from the given, write output into memory

    expected = get_expected_matmul(A, B)
    results = []

    await ClockCycles(dut.clk, 3)

    for i in range(4):
        dut.uio_in.value = (1 << 4)  # output_en = 1
        await ClockCycles(dut.clk, 1)
        val = dut.uo_out.value.integer
        results.append(val)
        dut._log.info(f"Read C[{i//2}][{i%2}] = {val}")
        dut.uio_in.value = 0
        await ClockCycles(dut.clk, 1)

    # ------------------------------
    # STEP 5: Check results
    for i in range(4):
        assert results[i] == expected[i], f"C[{i//2}][{i%2}] = {results[i]} != expected {expected[i]}"

    # Use output as input for next multiplication (i.e. load into "registers" from on-chip memory rather than input
    await ClockCycles(dut.clk, 1)

    await trigger_load_mem(dut, sel=0, addr=0)  # load A from memory addr 0
    await load_matrix(dut, B, sel=1)

    expected = get_expected_matmul(results, B)

    results = []

    await ClockCycles(dut.clk, 3)

    for i in range(4):
        dut.uio_in.value = (1 << 4)  # output_en = 1
        await ClockCycles(dut.clk, 1)
        val = dut.uo_out.value.integer
        results.append(val)
        dut._log.info(f"Read C[{i//2}][{i%2}] = {val}")
        dut.uio_in.value = 0
        await ClockCycles(dut.clk, 1)

    # ------------------------------
    # STEP 5: Check results
    for i in range(4):
        assert results[i] == expected[i], f"C[{i//2}][{i%2}] = {results[i]} != expected {expected[i]}"

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
    expected = get_expected_matmul(A, B)
    results = []

    await ClockCycles(dut.clk, 3)  # Wait for systolic array to compute
    
    dut._log.info(f"Read bidir output as {dut.uio_out.value}")

    for i in range(4):
        dut.uio_in.value = (1 << 4)  # output_en = 1
        await ClockCycles(dut.clk, 1)
        val = dut.uo_out.value.integer
        results.append(val)
        dut._log.info(f"Read C[{i//2}][{i%2}] = {val}")
        dut.uio_in.value = 0
        await ClockCycles(dut.clk, 1)

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

    await ClockCycles(dut.clk, 3)  # Wait for systolic array to compute
    
    for i in range(4):
        dut.uio_in.value = (1 << 4)  # output_en = 1
        await ClockCycles(dut.clk, 1)
        val = dut.uo_out.value.integer
        results.append(val)
        dut._log.info(f"Read C[{i//2}][{i%2}] = {val}")
        dut.uio_in.value = 0
        await ClockCycles(dut.clk, 1)

    # ------------------------------
    # STEP 5: Check results
    for i in range(4):
        assert results[i] == expected[i], f"C[{i//2}][{i%2}] = {results[i]} != expected {expected[i]}"

    dut._log.info("Test 2 passed!")