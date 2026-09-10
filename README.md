# MAC Tile

An in-progress signed multiply-accumulate (MAC) tile intended to grow from a
verified RTL block into a physical implementation and, ultimately, a GDSII
layout.

## Current design

The RTL currently implements a 2x2 systolic MAC array with 8-bit signed inputs
and 32-bit signed accumulators:

- `rtl/mac_pe.sv` — registered MAC processing element. It accumulates
  `a_in * b_in` and forwards both operands one cycle later.
- `rtl/mac_array_2x2.sv` — four processing elements arranged as a 2x2 array.
- `rtl/skew_unit.sv` — feeds 2x2 matrix operands to the array in the required
  skewed order.
- `tb/` — self-checking SystemVerilog testbenches for each block.

The checked-in OpenLane-style `config.json` names `mac_array_2x2` as the
physical-design top level, uses `clk` as the clock, and starts with a 400 um by
400 um die area and a 10 ns clock period.

## Quick start

Requirements: GNU Make, Verilator, Icarus Verilog, Yosys, and OpenSTA. Sky130
synthesis additionally needs the Sky130 standard-cell Liberty files available
under `/foss/pdks`, or `SKY130_LIB` set to the desired Liberty file.

```sh
# Check the default skew-unit testbench
make lint
make sim

# Select another testbench/design pair
make TOP=tb_mac_pe DUT=mac_pe lint sim
make TOP=tb_mac_array_2x2 DUT=mac_array_2x2 lint sim

# Generate generic or Sky130-mapped netlists and timing reports
make DUT=mac_array_2x2 synth
make DUT=mac_array_2x2 synth-sky130 sta
```

Simulation produces `dump.vcd`; view it with `make wave`. Build outputs are
intentionally untracked and can be removed with `make clean`.

## Toward a hardened tile and GDSII

1. Define the tile boundary: data/control interfaces, accumulator readout,
   reset/clock behavior, and parameterization for the intended array size.
2. Integrate and verify the skew unit with the MAC array at the tile top level;
   add matrix-level end-to-end and randomized tests.
3. Add implementation constraints: clock definition, IO placement, floorplan,
   power intent/grid, and macro requirements if applicable.
4. Run synthesis, static timing analysis, placement, CTS, routing, antenna/DRC
   repair, and signoff checks using an OpenLane/OpenROAD flow.
5. Archive the reproducible flow configuration and signoff reports, then export
   the final GDSII only after DRC/LVS and timing closure are clean.

`runs/`, `obj_dir/`, physical results, reports, and waveform files remain out
of Git because they are reproducible artifacts rather than design source.
