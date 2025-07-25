# Makefile
# See https://docs.cocotb.org/en/stable/quickstart.html for more info

# defaults
SIM ?= icarus
TOPLEVEL_LANG ?= verilog
SRC_DIR = $(PWD)/../src
PROJECT_SOURCES =	$(SRC_DIR)/tpu.v \
 				  	$(SRC_DIR)/systolic_array_2x2.v \
					$(SRC_DIR)/control_unit.v \
					$(SRC_DIR)/PE.v \
					$(SRC_DIR)/mmu_feeder.v \
					$(SRC_DIR)/memory.v

TEST_TPU_SOURCES = $(PWD)/top_tpu/tb.v
TEST_MMU_FEEDER_SOURCES = $(PWD)/mmu_feeder/tb_mmu_feeder.v


ifneq ($(GATES),yes)

# RTL simulation:
SIM_BUILD				= sim_build/rtl
VERILOG_SOURCES += $(addprefix $(SRC_DIR)/,$(PROJECT_SOURCES))

else

# Gate level simulation:
SIM_BUILD		= sim_build/gl
COMPILE_ARGS    += -DGL_TEST
COMPILE_ARGS    += -DFUNCTIONAL
COMPILE_ARGS    += -DSIM
VERILOG_SOURCES += $(PDK_ROOT)/ihp-sg13g2/libs.ref/sg13g2_io/verilog/sg13g2_io.v
VERILOG_SOURCES += $(PDK_ROOT)/ihp-sg13g2/libs.ref/sg13g2_stdcell/verilog/sg13g2_stdcell.v

# this gets copied in by the GDS action workflow
VERILOG_SOURCES += $(PWD)/gate_level_netlist.v

endif

# Allow sharing configuration between design and testbench via `include`:
COMPILE_ARGS 		+= -I$(SRC_DIR)

.PHONY: all test-feeder test-tpu cleanall

all: test-feeder test-tpu

test-feeder:
	$(MAKE) clean
	$(MAKE) sim \
		MODULE=test_mmu_feeder \
		TOPLEVEL=tb \
		VERILOG_SOURCES=$(TEST_MMU_FEEDER_SOURCES) \
		VERILOG_SOURCES+=$(SRC_DIR)/mmu_feeder.v \
		PYTHONPATH=$(PWD)/mmu_feeder \
		WAVES_DIR=$(PWD)/mmu_feeder/wave \
		COMPILE_ARGS=-I$(SRC_DIR) \
		SIM_BUILD=$(SIM_BUILD)

test-tpu:
	$(MAKE) clean
	$(MAKE) sim \
		MODULE=test \
		TOPLEVEL=tb \
		VERILOG_SOURCES=$(PROJECT_SOURCES) \
		VERILOG_SOURCES+=$(TEST_TPU_SOURCES) \
		PYTHONPATH=$(PWD)/top_tpu \
		WAVES_DIR=$(PWD)/top_tpu/wave \
		COMPILE_ARGS=-I$(SRC_DIR) \
		SIM_BUILD=$(SIM_BUILD)

cleanall:
	rm -rf sim_build* results.xml __pycache__ *.vcd */*.vcd

include $(shell cocotb-config --makefiles)/Makefile.sim