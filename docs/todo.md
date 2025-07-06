## RTL

- Incorporate on-chip memory R/W
- Add functionality for FP8 multiplication (and BF16 accumulation)
- Compress timing to enhance load-compute parallelism
- Enhance memory hierarchy with burst loads/writes into external Raspberry Pi
    - Who will track the addresses (i.e. where to read & write) ? Ideally both host & device need some info...
    - What signalling pattern will be used?

## Testbench

- Individual tests for PE and systolic array modules

## Other

- Resolve linter + synthesis warnings
- Update block diagram (need to show the 8 input, 8 output, and 8 bidirectional port usage)