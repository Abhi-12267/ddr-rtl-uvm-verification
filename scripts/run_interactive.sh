#!/bin/tcsh -f

set TOP = `dirname $0`/..
cd $TOP

echo "Starting interactive DDR session"
echo "This launches irun with waveform probes and leaves the simulator open."

irun -64 -sv -uvm \
  -timescale 1ns/1ps \
  -coverage all \
  -covoverwrite \
  -access +rwc \
  -f filelist.f \
  +UVM_TESTNAME=smoke_test \
  +UVM_VERBOSITY=UVM_MEDIUM \
  -input interactive/interactive_waves.tcl
