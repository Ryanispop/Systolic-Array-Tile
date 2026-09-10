# Shared HDL build targets.

TOP ?= tb_top
DUT ?= top

RTL_DIR ?= rtl
TB_DIR ?= tb
BUILD_DIR ?= build
SYNTH_DIR ?= synth
REPORT_DIR ?= reports

SKY130_LIB ?= $(shell find /foss/pdks -name "sky130_fd_sc_hd__tt_025C_1v80.lib" | head -1)

.PHONY: help dirs lint sim sim-iverilog wave synth synth-sky130 sta clean

help:
	@echo "Targets: lint sim sim-iverilog wave synth synth-sky130 sta clean"

dirs:
	mkdir -p $(BUILD_DIR) $(SYNTH_DIR) $(REPORT_DIR)

lint:
	verilator --lint-only -Wall rtl/*.sv tb/$(TOP).sv --top-module $(TOP)

sim:
	verilator --binary -Wall --trace rtl/*.sv tb/$(TOP).sv --top-module $(TOP)
	./obj_dir/V$(TOP)

sim-iverilog:
	mkdir -p $(BUILD_DIR)
	iverilog -g2012 -o $(BUILD_DIR)/$(TOP).out $(RTL_DIR)/*.sv $(TB_DIR)/$(TOP).sv
	vvp $(BUILD_DIR)/$(TOP).out

wave:
	gtkwave dump.vcd

synth:
	mkdir -p $(SYNTH_DIR) $(REPORT_DIR)
	yosys -p "read_verilog -sv $(RTL_DIR)/*.sv; hierarchy -top $(DUT); proc; opt; techmap; opt; stat; write_verilog $(SYNTH_DIR)/$(DUT)_generic.v" | tee $(REPORT_DIR)/yosys_generic.log

$(SYNTH_DIR)/$(DUT)_sky130.v: $(RTL_DIR)/*.sv
	mkdir -p $(SYNTH_DIR) $(REPORT_DIR)
	@test -n "$(SKY130_LIB)" || (echo "ERROR: SKY130_LIB not found"; exit 1)
	yosys -p "read_verilog -sv $(RTL_DIR)/*.sv; hierarchy -top $(DUT); synth -top $(DUT); dfflibmap -liberty $(SKY130_LIB); abc -liberty $(SKY130_LIB); clean; write_verilog $(SYNTH_DIR)/$(DUT)_sky130.v" | tee $(REPORT_DIR)/yosys_sky130.log

synth-sky130: $(SYNTH_DIR)/$(DUT)_sky130.v

$(SYNTH_DIR)/$(DUT).sdc:
	mkdir -p $(SYNTH_DIR)
	echo "create_clock -name clk -period 10 [get_ports clk]" > $(SYNTH_DIR)/$(DUT).sdc

sta: $(SYNTH_DIR)/$(DUT)_sky130.v $(SYNTH_DIR)/$(DUT).sdc
	mkdir -p $(BUILD_DIR) $(REPORT_DIR)
	echo "read_liberty $(SKY130_LIB)" > $(BUILD_DIR)/sta.tcl
	echo "read_verilog $(SYNTH_DIR)/$(DUT)_sky130.v" >> $(BUILD_DIR)/sta.tcl
	echo "link_design $(DUT)" >> $(BUILD_DIR)/sta.tcl
	echo "read_sdc $(SYNTH_DIR)/$(DUT).sdc" >> $(BUILD_DIR)/sta.tcl
	echo "report_checks" >> $(BUILD_DIR)/sta.tcl
	sta < $(BUILD_DIR)/sta.tcl | tee $(REPORT_DIR)/sta.log

clean:
	rm -rf obj_dir $(BUILD_DIR) $(SYNTH_DIR) $(REPORT_DIR) dump.vcd *.vcd
