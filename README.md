# MAC Tile

An in-progress signed multiply-accumulate (MAC) tile intended to grow from a
verified RTL block into a physical implementation and, ultimately, a GDSII
layout.

## Current design

`rtl/mac_tile.sv` integrates input buffers, a parameterized systolic MAC array,
operand skewing, a controller FSM, and an output buffer. It computes signed
square matrix multiplication `C = A * B`, with defaults of `N=2`, `DATA_W=8`,
and `ACC_W=32`. The original standalone 2x2 blocks remain available:

- `rtl/mac_pe.sv` — registered MAC processing element. It accumulates
  `a_in * b_in` and forwards both operands one cycle later.
- `rtl/mac_array_2x2.sv` — four processing elements arranged as a 2x2 array.
- `rtl/skew_unit.sv` — feeds 2x2 matrix operands to the array in the required
  skewed order.
- `tb/` — self-checking SystemVerilog testbenches for each block.

The checked-in LibreLane `config.json` targets `mac_tile` with Sky130 HD,
`N=2`, `DATA_W=8`, `ACC_W=32`, a 400 um by 400 um die, and a 30 ns clock target.

## Quick start

Requirements: GNU Make, Verilator, Icarus Verilog, Yosys, and OpenSTA. Sky130
synthesis additionally needs the Sky130 standard-cell Liberty files available
under `/foss/pdks`, or `SKY130_LIB` set to the desired Liberty file.

```sh
# Check and simulate the complete tile (writes dump.vcd)
make tile-lint tile-sim

# Run tile parameter sweeps plus existing PE/array/skew tests
make tile-test

# Simulate a custom tile using the local build rules
make -f common.mk TOP=tb_mac_tile DUT=mac_tile \
    VERILATOR_FLAGS='-GN=4 -GDATA_W=8 -GACC_W=24' lint sim

# Select another testbench/design pair
make TOP=tb_mac_pe DUT=mac_pe lint sim
make TOP=tb_mac_array_2x2 DUT=mac_array_2x2 lint sim

# Generate generic or Sky130-mapped netlists and timing reports
make DUT=mac_array_2x2 synth
make DUT=mac_array_2x2 synth-sky130 sta

# Generic synthesis of the integrated tile with default parameters
make -f common.mk DUT=mac_tile synth
```

Simulation produces `dump.vcd`; view it with `make wave`. Build outputs are
intentionally untracked and can be removed with `make clean`.

## Tile interface and timing

The tile has separate register banks for two input matrices and one result
matrix. It handles one transaction at a time; loading, computation, and result
retrieval do not overlap. These buffers are registers, not SRAM macros.

| Signal | Contract |
| --- | --- |
| `clk`, `rst` | Rising-edge clock and active-high synchronous reset. Reset aborts work and clears buffers and the array. Handshake outputs are disabled while reset is asserted. |
| `in_valid`, `in_ready` | Both high on a rising edge accepts and snapshots the complete `in_a` and `in_b` matrices, automatically starting computation. |
| `in_a`, `in_b` | Packed `N*N*DATA_W`-bit matrices; each element is signed two's complement. |
| `out_valid`, `out_ready` | Both high on a rising edge consumes the buffered result. Result data and valid remain stable during a stall. |
| `out_c` | Packed `N*N*ACC_W`-bit result, meaningful when `out_valid` is high. Each element is signed two's complement. |
| `busy` | High from input acceptance through result consumption. Additional inputs are blocked during this interval. |

All matrices use row-major packing, with element `[row][col]` at
`[(row*N+col)*WIDTH +: WIDTH]`. For a 2x2 input, pack
`{A11, A10, A01, A00}`. Keep input valid and data stable until accepted; inputs
may change immediately afterward. A producer may present the next request
while busy but must hold it until `in_ready` returns.

The FSM progresses through `IDLE -> CLEAR -> FEED -> DRAIN -> CAPTURE -> RESULT`.
Feeding takes `2*N-1` cycles and draining takes `N-1` cycles (`N=1` skips
`DRAIN`). Capturing on the next edge includes the last PE update.
`out_valid` asserts exactly `3*N` clocks after acceptance: six for the default
2x2 tile. A result cannot be consumed on its capture edge; the earliest is the
next rising edge. After consumption, the next request can be accepted on the
following edge.

Use positive integer parameters `N`, `DATA_W`, and `ACC_W`. Arithmetic wraps
modulo `2**ACC_W`; there is no saturation or overflow flag. For full-precision
dot products, use at least `2*DATA_W + $clog2(N)` accumulator bits. The current
testbench supports `DATA_W=2..16` and `ACC_W=1..32` and checks directed and
randomized matrices, the final drain multiply, output stalls, repeat requests,
reset during every phase, and deliberate accumulator overflow. `make tile-test`
covers array sizes 1 through 4 and several data/accumulator widths.

## Running LibreLane

With LibreLane and the Sky130 PDK installed, run from this directory:

```sh
librelane --manual-pdk --pdk-root /foss/pdks \
    --pdk sky130A --scl sky130_fd_sc_hd --flow Classic -j 4 config.json
```

These explicit PDK flags override this environment's default IHP selection.
Change `--pdk-root` if your PDKs are installed elsewhere. Outputs go into a new
ignored `runs/` directory. To stop after synthesis and early timing analysis,
add `--to OpenROAD.STAPrePNR`. A completed full run places GDS and other views
under `runs/<run-tag>/final/`; inspect the timing, DRC, LVS, and antenna reports
before accepting the result.

`constraints/pin_order.cfg` places matrix inputs west, results east, clock and
input controls north, and status outputs south. `constraints/mac_tile.sdc`
applies to both implementation and signoff: 20% of the clock period for maximum
input/output delays, 0.5 ns minimum input delay, -0.5 ns minimum output delay,
0.2 ns input transition, 10 fF output load, and 0.25 ns clock uncertainty.
These are initial external-interface assumptions, not measured requirements.
Synchronous reset is timed; no false-path exceptions are applied.

The 30 ns target replaces an initial 20 ns trial that missed slow-corner
pre-layout setup timing. Early synthesis/STA is not routed timing closure;
placement and CTS must still address hold, slew, and capacitance violations.
Only missing-timescale warnings in generated library black boxes are suppressed
in addition to LibreLane's default black-box suppressions; RTL checks remain on.

The tested tool version is LibreLane `3.1.0.dev1`. Set `SYNTH_PARAMETERS` to
change tile dimensions and widths, and reassess pin capacity, die size, and
timing when scaling the design. This flow builds a core block, without a pad ring.
Configuration reference: [LibreLane step variables](https://librelane.readthedocs.io/en/latest/reference/step_config_vars.html).

## Toward a hardened tile and GDSII

1. Choose the target tile size and external interface. The current parallel
   matrix ports favor simple testing; larger tiles may need streamed loading
   and result readout, SRAM buffers, or ping-pong banks.
2. Run the supplied `mac_tile` configuration and review synthesis and timing
   reports before tuning the clock target and floorplan.
3. Add implementation constraints: clock definition, IO placement, floorplan,
   power intent/grid, and macro requirements if applicable.
4. Run synthesis, static timing analysis, placement, CTS, routing, antenna/DRC
   repair, and signoff checks using an OpenLane/OpenROAD flow.
5. Archive the reproducible flow configuration and signoff reports, then export
   the final GDSII only after DRC/LVS and timing closure are clean.

`runs/`, `obj_dir/`, physical results, reports, and waveform files remain out
of Git because they are reproducible artifacts rather than design source.
