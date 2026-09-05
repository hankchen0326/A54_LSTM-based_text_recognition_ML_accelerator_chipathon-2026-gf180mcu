# A54 A-block wrapper

This directory contains a separate physical-design wrapper for the existing
`lstm16x_top` RTL.  The LSTM implementation is unchanged.  The new top-level
module, `A54_A`, exposes exactly the internal pad-cell terminals specified by
the organizer's latest `A54_A.def` template.

Physical requirements:

- origin: `(0, 0)`
- die/PR boundary: `1110 um x 1110 um`
- DEF template: `organizer_def/A54/project_defs/A/A54_A.def`
- final top cell: `A54_A`
- external pad assignments: 22 entries in `info.yaml`
- internal pad-cell interface terminals: 125, exactly matching the DEF template

The response pads are configured as outputs (`OE=1`, `IE=0`) with weak pulls
disabled.  Clock, reset, command-valid, and command-data pads are configured as
inputs with weak pulls disabled.

The current signoff-complete implementation is in the LibreLane run
`synthesis/runs/A54_A_wrapper_strong_power3`. Its final DEF contains the same die area,
pin names, pin uses, pin directions, and absolute pin geometries as the organizer
template. The submitted GDS also contains one top-level boundary shape on layer
0/0 from `(0, 0)` to `(1110, 1110) um`.

For integration safety, the submitted `gds/A54_A.gds` was re-streamed with
KLayout PCell and library context information disabled
(`SaveLayoutOptions.write_context_info = false`). A geometry XOR against the
signoff source GDS reports 0 differences. Magic DRC and Netgen LVS were then
rerun directly on this context-free GDS and both passed (DRC count 0; circuits
match uniquely).

The submitted GDS database unit is 0.001 um, as required for reliable KLayout
DRC. A 0.001 um to 0.005 um integration conversion and back to 0.001 um was
also tested; the round-trip geometry XOR reports 0 differences and preserves
the `(0, 0)` to `(1110, 1110) um` physical boundary.

The organizer DEF's VDD and VSS terminals each consist of six separate Metal2
port shapes. The strengthened implementation connects all six access shapes on
each net to the core power grid with six independent 2.0 um-wide Metal2 straps.
Each strap uses four `Via1_2CUT_H` arrays (eight cuts), for 24 via arrays and 48
cuts per supply net. This replaces the previous single 0.6 um Metal2 branch and
single-cut via while preserving every organizer pin shape.

Run the wrapper RTL test from this directory:

```sh
iverilog -g2012 -o tb_A54_A.vvp tb/tb_A54_A.sv rtl/A54_A.v rtl/core/*.v
vvp tb_A54_A.vvp
```

The expected final line is `WRAPPER PASS: signature=a8`.

## Final strong_power3 signoff results

- detailed-route DRC: 0
- Magic DRC: 0
- Netgen LVS: circuits match uniquely; all reported mismatch counts are 0
- KLayout-versus-Magic stream-out XOR: 0 differences
- final-route antenna: 0 violating nets and 0 violating pins
- setup and hold: WNS/TNS and violation counts are 0 in all nine reported corners
- maximum slew, capacitance, and fanout violations: 0 in all nine corners
- standard-cell utilization: 66.0073%
- sequential cells / functional clock sinks: 3042 / 3042
- VDD worst IR drop: 0.0133624 V (0.267% of 5 V)
- VSS worst ground rise: 0.0148959 V (0.298% of 5 V)
- OpenROAD power-grid connectivity: all shapes connected on both VDD and VSS

Raw reports are included under `verification/` in the submission package. The
GF180 LibreLane configuration used here does not provide a separate KLayout DRC
runset; the available signoff physical deck is Magic DRC, while stream-out
equivalence is independently checked by KLayout-versus-Magic XOR.
