# test/Makefile

# Defaults
SIM ?= icarus
TOPLEVEL_LANG ?= verilog

SRC_DIR := $(PWD)/../src
FEEDER_DIR := $(PWD)/mmu_feeder
# TPU_DIR := $(PWD)/top_tpu

# Common flags
COMPILE_ARGS += -I$(SRC_DIR)

# Optional gate sim support
ifeq ($(GATES),yes)
  SIM_BUILD := sim_build/gl
  COMPILE_ARGS += -DGL_TEST -DFUNCTIONAL -DSIM
  VERILOG_GATE_SOURCES := \
    $(PDK_ROOT)/ihp-sg13g2/libs.ref/sg13g2_io/verilog/sg13g2_io.v \
    $(PDK_ROOT)/ihp-sg13g2/libs.ref/sg13g2_stdcell/verilog/sg13g2_stdcell.v \
    $(PWD)/gate_level_netlist.v
else
  SIM_BUILD := sim_build/rtl
endif

# RTL source lists
RTL_SOURCES = \
    $(SRC_DIR)/tpu.v \
    $(SRC_DIR)/systolic_array_2x2.v \
    $(SRC_DIR)/control_unit.v \
    $(SRC_DIR)/PE.v \
    $(SRC_DIR)/mmu_feeder.v

TEST_MMU_FEEDER_SOURCES = $(PWD)/mmu_feeder/tb_mmu_feeder.v
# TEST_TPU_SOURCES = $(PWD)/top_tpu/tb.v

.PHONY: all test-feeder cleanall

all: test-feeder

test-feeder:
	$(MAKE) clean
	$(MAKE) sim \
		MODULE=test_mmu_feeder \
		TOPLEVEL=tb \
		VERILOG_SOURCES="$(TEST_BF16_SOURCES) $(SRC_DIR)/tb_mmu_feeder.v" \
		PYTHONPATH=$(PWD)/mmu_feeder \
		WAVES_DIR=$(PWD)/mmu_feeder/wave \
		COMPILE_ARGS=-I$(SRC_DIR) \
		SIM_BUILD=$(SIM_BUILD)

# test-tpu:
# 	$(MAKE) clean
# 	$(MAKE) sim \
# 		MODULE=test \
# 		TOPLEVEL=tb \
# 		VERILOG_SOURCES="$(TEST_TPU_SOURCES) $(RTL_SOURCES)" \
# 		PYTHONPATH=$(PWD)/top_tpu \
# 		WAVES_DIR=$(PWD)/top_tpu/wave \
# 		COMPILE_ARGS=-I$(SRC_DIR) \
# 		SIM_BUILD=$(SIM_BUILD)

cleanall:
	rm -rf sim_build* results.xml __pycache__ *.vcd */*.vcd

include $(shell cocotb-config --makefiles)/Makefile.sim