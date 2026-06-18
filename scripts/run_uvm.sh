#!/bin/tcsh -f

set TOP = `dirname $0`/..
cd $TOP

if ($#argv >= 1) then
  set TEST = $argv[1]
else
  set TEST = smoke_test
endif

echo "Running DDR UVM test: $TEST"

irun -64 -sv -uvm \
  -timescale 1ns/1ps \
  -coverage all \
  -covoverwrite \
  -access +rwc \
  -f filelist.f \
  +UVM_TESTNAME=$TEST \
  +UVM_VERBOSITY=UVM_MEDIUM \
  -input waves.tcl \
  >& ddr_uvm_run.log

set RC = $status
cat ddr_uvm_run.log

set UVME = `grep "UVM_ERROR :" ddr_uvm_run.log | tail -1 | awk '{print $3}'`
set UVMF = `grep "UVM_FATAL :" ddr_uvm_run.log | tail -1 | awk '{print $3}'`
if ("$UVME" == "") set UVME = 999
if ("$UVMF" == "") set UVMF = 999

if (($UVME != 0) || ($UVMF != 0)) then
  echo "Simulation failed by UVM summary: UVM_ERROR=$UVME UVM_FATAL=$UVMF (rc=$RC)"
  exit 1
endif

if (-d ddr_waves.shm) then
  simvisdbutil -vcd ddr_waves.shm -output ddr_waves.vcd -overwrite
  if ($status == 0) then
    vcd2fsdb ddr_waves.vcd -o ddr_waves.fsdb
  endif
endif

echo ""
echo "Run complete: $TEST"
echo "Open Verdi: verdi -sv -uvm -f filelist.f -top tb_top -ssf ddr_waves.fsdb &"
