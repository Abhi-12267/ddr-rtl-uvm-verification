.PHONY: uvm smoke timing refresh random stress interactive verdi_interactive interactive_then_verdi clean

UVM_TEST ?= smoke_test
TEST ?= smoke_test

uvm:
	irun -64 -sv -uvm \
	  -timescale 1ns/1ps \
	  -coverage all \
	  -covoverwrite \
	  -access +rwc \
	  -f filelist.f \
	  +UVM_TESTNAME=$(UVM_TEST) \
	  +UVM_VERBOSITY=UVM_MEDIUM \
	  -input waves.tcl | tee ddr_uvm_run.log

smoke:
	$(MAKE) uvm UVM_TEST=smoke_test

timing:
	$(MAKE) uvm UVM_TEST=timing_test

refresh:
	$(MAKE) uvm UVM_TEST=refresh_test

random:
	$(MAKE) uvm UVM_TEST=random_test

stress:
	$(MAKE) uvm UVM_TEST=stress_test

interactive:
	./scripts/run_interactive.sh

verdi_interactive:
	./scripts/run_verdi_interactive.sh

interactive_then_verdi:
	./scripts/run_interactive_then_verdi.sh $(TEST)

clean:
	rm -rf INCA_libs irun.* ncvlog.* ncelab.* ncsim.* *.log ddr_waves.shm ddr_waves.vcd ddr_waves.fsdb
