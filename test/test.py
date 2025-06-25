
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles
from cocotb.binary import BinaryValue

# Helper function to perform matrix multiplication in Python (with saturation)
def matrix_multiply_python(matrix_a, matrix_b):
    result_c = [[0, 0], [0, 0]]
    for i in range(2):
        for j in range(2):
            acc_val = 0
            for k in range(2):
                acc_val += matrix_a[i][k] * matrix_b[k][j]
            # Apply saturation to 8-bit unsigned integer (0-255)
            if acc_val > 255:
                result_c[i][j] = 255
            elif acc_val < 0: # Should not happen with unsigned, but good practice
                result_c[i][j] = 0
            else:
                result_c[i][j] = acc_val
    return result_c

@cocotb.test()
async def test_project(dut):
    dut._log.info("Starting TPU Matrix Test")

    # Set the clock period to 10 us (100 KHz)
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())

    # Reset the DUT
    dut._log.info("Resetting DUT")
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0  # All uio_in control signals to 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    dut._log.info("DUT Reset Complete")
    await ClockCycles(dut.clk, 2) # Give a couple cycles after reset for stability


    # Define a list of test matrices (A, B pairs)
    test_cases = [
        # Case 1: Simple Identity-like
        ([[1, 0], [0, 1]], [[5, 6], [7, 8]]), # Expect [[5, 6], [7, 8]]

        # Case 2: Standard small values
        ([[1, 2], [3, 4]], [[5, 6], [7, 8]]), # Expect [[19, 22], [43, 50]]
        
        # Case 3: Larger values, no overflow
        ([[10, 15], [20, 25]], [[1, 2], [3, 4]]), # Expect [[55, 80], [95, 140]]

        # Case 4: Values designed to cause saturation
        ([[100, 100], [100, 100]], [[1, 1], [1, 1]]), # A00*B00 + A01*B10 = 100*1 + 100*1 = 200 (no sat)
                                                     # A00*B01 + A01*B11 = 100*1 + 100*1 = 200 (no sat)
                                                     # Expect [[200, 200], [200, 200]]

        # Case 5: More severe saturation (e.g., max value * max value)
        # Note: 255*255 + 255*255 = 130050. Saturated to 255.
        ([[255, 255], [255, 255]], [[255, 255], [255, 255]]) # Expect [[255, 255], [255, 255]]
    ]

    for test_idx, (matrix_a_in, matrix_b_in) in enumerate(test_cases):
        dut._log.info(f"--- Test Case {test_idx + 1} ---")
        dut._log.info(f"Matrix A: {matrix_a_in}")
        dut._log.info(f"Matrix B: {matrix_b_in}")

        # Calculate expected C matrix using Python model
        expected_c = matrix_multiply_python(matrix_a_in, matrix_b_in)
        dut._log.info(f"Expected C: {expected_c}")

        # --- Load Matrix A ---
        dut._log.info("Loading Matrix A...")
        # load_en = 1 (uio_in[0]), load_sel_ab = 0 (uio_in[1] = 0)
        # uio_in format: {uio_in[7], uio_in[6:5] (output_sel), uio_in[4] (output_en), uio_in[3:2] (load_index), uio_in[1] (load_sel_ab), uio_in[0] (load_en)}
        for r in range(2):
            for c in range(2):
                idx = r * 2 + c # Linear index 0-3
                dut.ui_in.value = matrix_a_in[r][c]
                dut.uio_in.value = BinaryValue(f"0000{idx:02b}01", n_bits=8) # set load_en=1, load_sel_ab=0, load_index
                dut._log.info(f"Loading A[{r}][{c}] ({idx}) = {matrix_a_in[r][c]}")
                await ClockCycles(dut.clk, 1)
        
        dut.uio_in.value = 0 # De-assert load_en and all other control signals
        await ClockCycles(dut.clk, 1) # Give a cycle for flags to register if needed

        # --- Load Matrix B ---
        dut._log.info("Loading Matrix B...")
        # load_en = 1 (uio_in[0]), load_sel_ab = 1 (uio_in[1] = 1)
        for r in range(2):
            for c in range(2):
                idx = r * 2 + c # Linear index 0-3
                dut.ui_in.value = matrix_b_in[r][c]
                dut.uio_in.value = BinaryValue(f"0000{idx:02b}11", n_bits=8) # set load_en=1, load_sel_ab=1, load_index
                dut._log.info(f"Loading B[{r}][{c}] ({idx}) = {matrix_b_in[r][c]}")
                await ClockCycles(dut.clk, 1)
        
        dut.uio_in.value = 0 # De-assert load_en and all other control signals
        await ClockCycles(dut.clk, 1)

        # --- Trigger Calculation and Wait for Done ---
        dut._log.info("Triggering calculation and waiting for 'done' signal...")
        # The controller automatically triggers 'start_mmu' when A & B are loaded.
        # We just need to wait for the 'done' signal from the DUT's uio_out[7].
        # The 'done' signal is driven by uio_out[7]

        timeout_cycles = 10 # Max cycles to wait for done (should be around 5 for systolic + 1-2 buffer)
        for _ in range(timeout_cycles):
            if dut.uio_out.value.binstr[0] == '1': # Check uio_out[7] for done signal
                dut._log.info("Calculation 'done' received!")
                break
            await ClockCycles(dut.clk, 1)
        else:
            dut._log.error("Timeout: 'done' signal not received!")
            raise cocotb.result.TestFailure("Calculation did not complete in time.")
        
        await ClockCycles(dut.clk, 1) # Wait one more cycle for outputs to settle if done pulsed

        # --- Read and Verify Result Matrix C ---
        dut._log.info("Reading and verifying Matrix C...")
        for r in range(2):
            for c in range(2):
                idx = r * 2 + c # Linear index 0-3
                # output_en = 1 (uio_in[4]), output_sel = idx (uio_in[6:5])
                dut.uio_in.value = BinaryValue(f"0{idx:02b}10000", n_bits=8) # set output_en=1, output_sel=idx
                await ClockCycles(dut.clk, 1)
                
                actual_c_val = dut.uo_out.value.integer
                expected_c_val = expected_c[r][c]
                
                dut._log.info(f"C[{r}][{c}] (idx {idx}): Expected = {expected_c_val}, Actual = {actual_c_val}")
                assert actual_c_val == expected_c_val, \
                    f"C[{r}][{c}] Mismatch! Expected: {expected_c_val}, Actual: {actual_c_val}"
        
        dut.uio_in.value = 0 # De-assert output_en and other control signals
        await ClockCycles(dut.clk, 2) # Small delay before next test case

    dut._log.info("All matrix test cases passed!")