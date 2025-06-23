# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge

def encode_ctrl(load_en=0, load_sel_ab=0, load_index=0, output_en=0, output_sel=0):
    ctrl = 0
    ctrl |= (load_en & 1) << 0
    ctrl |= (load_sel_ab & 1) << 1
    ctrl |= (load_index & 0b11) << 2
    ctrl |= (output_en & 1) << 4
    ctrl |= (output_sel & 0b11) << 5
    return ctrl

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

    # Load A matrix: [[1, 2], [3, 4]]
    A_vals = [1, 2, 3, 4]
    for i, val in enumerate(A_vals):
        dut.ui_in.value = val
        dut.uio_in.value = encode_ctrl(load_en=1, load_sel_ab=0, load_index=i)
        await ClockCycles(dut.clk, 1)

    # Load B matrix: [[5, 6], [7, 8]]
    B_vals = [5, 6, 7, 8]
    for i, val in enumerate(B_vals):
        dut.ui_in.value = val
        dut.uio_in.value = encode_ctrl(load_en=1, load_sel_ab=1, load_index=i)
        await ClockCycles(dut.clk, 1)

    # Clear control lines after loading
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    await ClockCycles(dut.clk, 1)

    # Wait for 'done' (bit 7 of uio_out to become 1)
    for _ in range(20):
        await RisingEdge(dut.clk)
        dut._log.info(f"uio_out = {dut.uio_out.value.binstr}")
        if dut.uio_out.value.integer & 0x80:
            break
    else:
        raise AssertionError("Timed out waiting for 'done' signal")

    # Read C matrix results
    C_expected = [
        1*5 + 2*7,   # 19
        1*6 + 2*8,   # 22
        3*5 + 4*7,   # 43
        3*6 + 4*8    # 50
    ]

    for i, expected in enumerate(C_expected):
        dut.uio_in.value = encode_ctrl(output_en=1, output_sel=i)
        await ClockCycles(dut.clk, 1)
        actual = dut.uo_out.value.integer
        assert actual == (expected & 0xFF), f"C[{i}] = {actual}, expected {expected & 0xFF}"

    dut._log.info("Matrix multiplication passed.")