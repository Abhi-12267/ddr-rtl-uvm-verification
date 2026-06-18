# DDR UVM Validation Starter (Cadence irun/Xcelium)

This repository is a **generic, educational DDR controller validation example** using:
- SystemVerilog RTL model
- UVM testbench
- Cadence `irun`/`ncsim` simulation flow
- SHM/VCD/FSDB waveform flow

It is designed to help learners understand DDR command timing/state validation, scoreboard checks, coverage, and debug workflows.

## What This Project Is

- A compact DDR command scheduler/controller model (`ACT/READ/WRITE/PRE/REF`)
- A full UVM environment: driver, monitors, predictor, scoreboard, coverage, sequences, tests
- Ready-to-run scripts for:
  - regression-style runs
  - interactive SimVision run
  - interactive run + auto-open Verdi

## What This Project Is Not

- Not a full JEDEC-complete DDR PHY/model
- Not a drop-in production DDR IP verification environment
- Not simulator-agnostic for all features (flow is currently Cadence-centric)

## Tool Requirements

## Required (current flow)
- Cadence Xcelium / Incisive (`irun`, `ncsim`, `simvisdbutil`)
- UVM library available in your Cadence installation

## Optional
- Synopsys Verdi (`verdi`, `vcd2fsdb`) for FSDB debug

## Is `irun` free?
No. `irun` is part of Cadence commercial EDA tools (licensed software).

Typical access models:
- Company/University floating license server
- Time-limited evaluation from vendor (if approved)

## Can this be run with free tools?
Partially, but with limitations:
- Basic SV might run in open-source simulators.
- Full UVM + this Cadence-oriented flow generally requires commercial simulators.

## Project Structure

```text
DDR_VAL/
  rtl/
    ddr_ctrl_model.sv
  uvm_tb/
    ddr_if.sv
    ddr_uvm_pkg.sv
    tb_top.sv
  scripts/
    run_uvm.sh
    run_interactive.sh
    run_verdi_interactive.sh
    run_interactive_then_verdi.sh
  interactive/
    interactive_waves.tcl
    INTERACTIVE_GUIDE.txt
    VERDI_LIVE_GUIDE.txt
  filelist.f
  waves.tcl
  Makefile
  STUDY_GUIDE.txt
```

## Quick Start (Batch)

```bash
cd DDR_VAL
make smoke
make timing
make refresh
make random
make stress
```

Or directly:

```bash
./scripts/run_uvm.sh smoke_test
./scripts/run_uvm.sh timing_test
./scripts/run_uvm.sh refresh_test
./scripts/run_uvm.sh random_test
./scripts/run_uvm.sh stress_test
```

## Waveforms and Verdi

The flow writes SHM and converts to VCD/FSDB.

Open Verdi:

```bash
verdi -sv -uvm -f filelist.f -top tb_top -ssf ddr_waves.fsdb &
```

## Interactive Debug Flows

## SimVision live debug
```bash
make interactive
```

## Verdi interactive mode attempt
```bash
make verdi_interactive
```

## Recommended practical flow (interactive sim, then auto-open Verdi)
```bash
make interactive_then_verdi TEST=smoke_test
```

Supported tests for this target:
- `smoke_test`
- `timing_test`
- `refresh_test`
- `random_test`
- `stress_test`

## Learning Scope

This repository is best for learners in:
- DDR command protocol basics
- Timing constraint checking in controller logic (`tRCD`, `tRAS`, `tRP`, `tCCD`)
- UVM architecture and reference-model-based checking
- Coverage and debug methodology

If your audience is beginner-to-intermediate DV engineers, this repo is useful and publishable as an educational template.

## What to Commit to GitHub

Commit these:
- `rtl/`
- `uvm_tb/`
- `scripts/`
- `interactive/`
- `protocol_rc/`
- `filelist.f`, `waves.tcl`, `Makefile`, `STUDY_GUIDE.txt`, `README.md`, `.gitignore`

Do **not** commit generated artifacts:
- `INCA_libs/`
- `cov_work/`
- `*.shm`, `*.vcd`, `*.fsdb`
- `irun.log`, `ddr_uvm_run.log`, `verdiLog/`, `vcd2fsdbLog/`

## Publishing Notes

Before publishing:
1. Ensure no company-internal paths, credentials, or proprietary RTL are included.
2. Keep this tagged as **educational/reference**.
3. Mention commercial tool requirement clearly (Cadence).
4. Add a license (MIT/BSD/Apache) based on your preference.

## Suggested GitHub Description

"Educational DDR SystemVerilog/UVM validation starter with Cadence irun flow, coverage, scoreboard, protocol timing checks, and interactive debug scripts."
