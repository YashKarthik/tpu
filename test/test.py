import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.binary import BinaryValue

# Helper to encode matrix to flat list
def flatten_matrix(matrix):
    return [matrix[i][j] for i in range(2) for j in range(2)]

@cocotb.test()
async def test_systolic_array(dut):
    dut._log.info("Starting TPU systolic array test")

    clk = dut.clk
    rst_n = dut.rst_n
    ui_in = dut.ui_in
    uio_in = dut.uio_in
    uo_out = dut.uo_out

    # Clock generation assumed handled externally or via Makefile/waveform

    async def reset():
        rst_n.value = 0
        await RisingEdge(clk)
        await RisingEdge(clk)
        rst_n.value = 1
        await RisingEdge(clk)
        await RisingEdge(clk)

    await reset()

    A = [[2, 3],
         [4, 5]]
    B = [[6, 7],
         [8, 9]]

    expected_C = [[2*6 + 3*8, 2*7 + 3*9],
                  [4*6 + 5*8, 4*7 + 5*9]]

    async def load_matrix(matrix, sel_ab):
        for i in range(2):
            for j in range(2):
                flat_idx = 2 * i + j
                uio_in.value = BinaryValue(f"000{int(sel_ab)}{flat_idx:02b}1", n_bits=8)
                ui_in.value = matrix[i][j]
                await RisingEdge(clk)
                uio_in.value = 0
                await RisingEdge(clk)

    # Load A and B
    await load_matrix(A, sel_ab=0)
    await load_matrix(B, sel_ab=1)

    # Wait for result
    uio_in.value = 0b00010000  # output_en=1
    for _ in range(10):
        await RisingEdge(clk)
        if int(dut.uio_out.value) & 0x80:
            break

    # Read result C
    results = []
    for idx in range(4):
        sel = BinaryValue(f"0{idx:02b}0000", n_bits=8)
        uio_in.value = sel
        await RisingEdge(clk)
        results.append(int(uo_out.value))

    # Print result
    C_actual = [results[0:2], results[2:4]]
    for i in range(2):
        for j in range(2):
            expected = expected_C[i][j] & 0xFF
            actual = C_actual[i][j]
            assert actual == expected, f"Mismatch at C[{i}][{j}]: expected {expected}, got {actual}"

    dut._log.info("Systolic array test passed")
