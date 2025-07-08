import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles


@cocotb.test()
async def test_weight_memory(dut):
    """
    Exercise the weight_memory block via the public load interface.

    * load_en         — uio_in[0]
    * load_index[1:0] — uio_in[3:2]
    * payload byte    — ui_in[7:0]

    After programming four distinct bytes we check that
    wmem.weight_1..weight_4 reflect the values.
    """

    # 10 ns clock
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    # Reset and enable the design
    dut.ena.value   = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 1)

    # Bytes we will store at addresses 0-3
    weights = [11, 22, 33, 44]

    async def program(addr, byte):
        """Pulse load_en for one cycle to write <byte> to <addr>."""
        dut.ui_in.value  = byte
        dut.uio_in.value = (addr << 2) | 0b00000001   # load_en=1
        await ClockCycles(dut.clk, 1)
        dut.uio_in.value = 0                          # de-assert
        await ClockCycles(dut.clk, 1)

    # Write four locations
    for a, b in enumerate(weights):
        await program(a, b)

    # Give the outputs a settling cycle
    await ClockCycles(dut.clk, 1)

    # Hierarchical access: tb → tpu_project → wmem
    wmem = dut.tpu_project.wmem

    assert int(wmem.weight_1.value) == weights[0], "weight_1 mismatch"
    assert int(wmem.weight_2.value) == weights[1], "weight_2 mismatch"
    assert int(wmem.weight_3.value) == weights[2], "weight_3 mismatch"
    assert int(wmem.weight_4.value) == weights[3], "weight_4 mismatch"

    dut._log.info("weight_memory self-test passed!")
