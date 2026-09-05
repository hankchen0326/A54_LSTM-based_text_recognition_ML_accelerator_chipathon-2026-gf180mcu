#!/usr/bin/env python3
"""Rewrite a GDS with KLayout PCell/library context information disabled."""

from __future__ import annotations

import argparse
from pathlib import Path

import pya  # type: ignore


def layout_facts(path: Path) -> tuple[float, list[str], int]:
    layout = pya.Layout()
    layout.read(str(path))
    return layout.dbu, sorted(cell.name for cell in layout.top_cells()), layout.cells()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("input_gds", type=Path)
    parser.add_argument("output_gds", type=Path)
    args = parser.parse_args()

    layout = pya.Layout()
    layout.read(str(args.input_gds))

    options = pya.SaveLayoutOptions()
    options.format = "GDS2"
    options.dbu = layout.dbu
    options.scale_factor = 1.0
    options.write_context_info = False
    options.gds2_write_cell_properties = False
    options.gds2_write_file_properties = False

    args.output_gds.parent.mkdir(parents=True, exist_ok=True)
    layout.write(str(args.output_gds), options)

    in_facts = (layout.dbu, sorted(cell.name for cell in layout.top_cells()), layout.cells())
    out_facts = layout_facts(args.output_gds)
    if in_facts != out_facts:
        raise RuntimeError(f"layout metadata changed: input={in_facts}, output={out_facts}")

    print("GDS EXPORT PASS")
    print("  write_context_info: false")
    print(f"  database unit: {out_facts[0]} um")
    print(f"  top cells: {', '.join(out_facts[1])}")
    print(f"  cell count: {out_facts[2]}")
    print(f"  output: {args.output_gds}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
