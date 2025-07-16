import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge

@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut.input_0.value = 0
    dut.input_1.value = 0
    dut.input_2.value = 0
    dut.input_3.value = 0
    dut.weight_0.value = 0
    dut.weight_1.value = 0
    dut.weight_2.value = 0
    dut.weight_3.value = 0
    dut.c_0.value = 0
    dut.c_1.value = 0
    dut.c_2.value = 0
    dut.c_3.value = 0
    dut.rst_n.value = 0
    dut.en.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5)

    dut._log.info("Enabling feeder module...")
    dut.en.value = 1
    R = [] # List to store results

    # ------------------------------
    # CYCLE 0: Start loading matrices from internal memory
    I = [1, 2, 3, 4]  # row-major: [I00, I01, I10, I11]
    W = [5, 6, 7, 8]  # row-major: [W00, W01, W10, W11]

    dut.mmu_cycles.value = 0

    dut.input_0.value = I[0]
    dut.weight_0.value = W[0]
    
    await RisingEdge(dut.clk)

    # ------------------------------
    # CYCLE 1: First partial products complete
    dut.mmu_cycles.value = 1

    dut.input_1.value = I[1]
    dut.input_2.value = I[2]
    dut.weight_1.value = W[1]
    dut.weight_2.value = W[2]

    dut.c_0.value = I[0] * W[0]  # Set c_0 value (data ready from mmu)

    await RisingEdge(dut.clk)

    # ------------------------------
    # CYCLE 2: c00 = a00xb00 ready, c00 outputted
    dut.mmu_cycles.value = 2

    dut._log.info(f"Cycle 2: c00 = {dut.c_0.value.integer}")
    dut.input_3.value = I[3]
    dut.weight_3.value = W[3]

    dut.c_1.value = I[1] * W[1]  # Set c_1 value (data ready from mmu)
    dut.c_2.value = I[2] * W[2] # Set c_2 value (data ready from mmu -> output_buf)

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk) # for latching (wait for c_0 to be stable)

    # dut._log.info(f"Cycle 3: host_outdata = {dut.host_outdata.value.integer}")
    R.insert(0,dut.host_outdata.value.integer)  # Store host_ output (c00 outputted)

    # ------------------------------
    # CYCLE 3: c01 = a00xb01 ready, c10 = a10xb00 ready, c01 outputted
    dut.mmu_cycles.value = 3
    await RisingEdge(dut.clk) # for latching (wait for c_1 & c_2 to be stable)

    dut._log.info(f"Cycle 3: c01 = {dut.c_1.value.integer}")

    dut.c_3.value = I[3] * W[3]  # Set c_3 value (data ready from mmu -> output_buf)

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk) # for latching (wait for c_1 to be stable)

    R.insert(1, dut.host_outdata.value.integer)  # Store host_ output (c01 outputted)
    
    # ------------------------------
    # CYCLE 4: c11 = a10xb01 ready, c10 outputted
    dut.mmu_cycles.value = 4

    dut._log.info(f"Cycle 4: c10 = {dut.c_2.value.integer}")

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk) # for latching (wait for c_2 to be stable)

    R.insert(2, dut.host_outdata.value.integer)  # Store host_ output (c10 outputted)

    # ------------------------------
    # CYCLE 5: c11 outputted
    dut.mmu_cycles.value = 5

    dut._log.info(f"Cycle 5: c11 = {dut.c_3.value.integer}")

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk) # for latching (wait for c_3 to be stable)

    R.insert(3, dut.host_outdata.value.integer)  # Store host_ output (c11 outputted)

    # ------------------------------
    # CHECK RESULTS
    expected = [5, 12, 21, 32]  # Expected results

    for i in range(4):
        assert R[i] == expected[i], f"R[{i}] = {R[i]} != expected {expected[i]}"
    
    dut._log.info("Test Passed: All results match expected values!")
