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

This package contains the final closed-ring implementation. It uses separate
30 um Metal5 rings for VDD and VSS. All six VDD and six VSS access shapes have
independent stacked-via entry paths. The generated Via2, Via3, and Via4 arrays
use a 0.66 um center pitch. With 0.26 um cuts, this gives 0.40 um cut-to-cut
spacing, above the 0.36 um requirement for arrays of 4x4 or larger. Each supply
ring is connected to the vertical Metal4 PDN through 10,080 Via4 cuts.

The final GDS has 0.001 um DBU and one exact 1110 um x 1110 um boundary on
layer 0/0. The organizer DEF comparison reports no changed, missing, or extra
terminals.

Run the wrapper RTL test from this directory:

```sh
iverilog -g2012 -o tb_A54_A.vvp tb/tb_A54_A.sv rtl/A54_A.v rtl/core/*.v
vvp tb_A54_A.vvp
```

The expected final line is `WRAPPER PASS: signature=a8`.

## Final signoff results

- Magic DRC: 0
- GF180 KLayout Via2 rules: 0 markers, including V2.2b
- GF180 KLayout Via3 rules: 0 markers, including V3.2b
- GF180 KLayout Via4 rules: 0 markers, including V4.2b
- Netgen LVS: circuits match uniquely; all reported mismatch counts are 0
- KLayout-versus-Magic stream-out XOR: 0 differences
- illegal overlap: 0
- VDD/VSS same-layer contacts: 0 on Metal1 through Metal5
- VDD worst IR drop: 0.00598 V (0.12% of 5 V)
- VSS worst ground rise: 0.0192 V (0.38% of 5 V)
- OpenROAD EM maximum reported current: 0.00373 A on VDD and 0.0106 A on VSS
- OpenROAD power-grid connectivity: all shapes connected on both VDD and VSS
- GDS DBU: 0.001 um
- boundary on layer 0/0: exactly 1110 um x 1110 um

Raw reports are included under `verification/`. The standard LibreLane GF180
configuration does not automatically run a KLayout deck, so the GF180 Via2,
Via3, and Via4 rule tables were also run directly against the final GDS. Their
original `.lyrdb` databases and logs are under
`verification/drc/klayout_via_rules/`.
