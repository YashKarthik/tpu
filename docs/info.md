<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

The controller initially takes 8 matrix values, 4 for each of 2 matrices. Each element is 1 byte.

Then they are fed either 2 or 4 at a time to the 2x2 systolic array containing 4 processing elements (PEs).

Each PE will contain one of the output matrix values, which are all computed within 4 cycles, but for which output extraction for the top-left element can begin after just 3 cycles.

## How to test

Enter the test directory at `test`.
Then for the top level test simply use `make` to trigger the makefile, which will run the test.

## External hardware

The Raspberry Pi will serve as an optional source of external memory.

External memory values will be received and written into via a pattern of handshakes.