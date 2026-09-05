#!/usr/bin/env python3
"""Create a 5 nm integration copy and a 1 nm round-trip copy of a GDS."""

from __future__ import annotations

import argparse
from pathlib import Path

import pya  # type: ignore


def write_at_dbu(layout: pya.Layout, path: Path, dbu: float) -> None:
    options = pya.SaveLayoutOptions()
    options.format = "GDS2"
    options.dbu = dbu
    options.scale_factor = 1.0
    options.write_context_info = False
    options.gds2_write_cell_properties = False
    options.gds2_write_file_properties = False
    path.parent.mkdir(parents=True, exist_ok=True)
    layout.write(str(path), options)


def facts(path: Path) -> tuple[float, list[str], tuple[float, float, float, float]]:
    layout = pya.Layout()
    layout.read(str(path))
    tops = sorted(cell.name for cell in layout.top_cells())
    if len(tops) != 1:
        raise RuntimeError(f"expected one top cell in {path}, found {tops}")
    box = layout.top_cell().bbox()
    bbox_um = tuple(value * layout.dbu for value in (box.left, box.bottom, box.right, box.top))
    return layout.dbu, tops, bbox_um


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("input_gds", type=Path)
    parser.add_argument("integration_gds_5nm", type=Path)
    parser.add_argument("roundtrip_gds_1nm", type=Path)
    args = parser.parse_args()

    original = pya.Layout()
    original.read(str(args.input_gds))
    write_at_dbu(original, args.integration_gds_5nm, 0.005)

    integration = pya.Layout()
    integration.read(str(args.integration_gds_5nm))
    write_at_dbu(integration, args.roundtrip_gds_1nm, 0.001)

    input_facts = facts(args.input_gds)
    integration_facts = facts(args.integration_gds_5nm)
    roundtrip_facts = facts(args.roundtrip_gds_1nm)
    if input_facts[1:] != integration_facts[1:] or input_facts[1:] != roundtrip_facts[1:]:
        raise RuntimeError(
            "top cell or physical bounding box changed: "
            f"input={input_facts}, integration={integration_facts}, roundtrip={roundtrip_facts}"
        )

    print("DBU ROUND-TRIP EXPORT PASS")
    print(f"  input DBU: {input_facts[0]} um")
    print(f"  integration DBU: {integration_facts[0]} um")
    print(f"  round-trip DBU: {roundtrip_facts[0]} um")
    print(f"  top cell: {input_facts[1][0]}")
    print(f"  physical bbox: {input_facts[2]} um")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
