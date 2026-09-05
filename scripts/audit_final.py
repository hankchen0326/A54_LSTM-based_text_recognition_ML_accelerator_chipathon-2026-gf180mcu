#!/usr/bin/env python3
"""Audit the A54 wrapper DEF template contract and final GDS boundary."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


def _number(value: str) -> int:
    return int(value)


def parse_def(path: Path) -> dict:
    text = path.read_text(encoding="utf-8", errors="replace")
    units_match = re.search(r"\bUNITS\s+DISTANCE\s+MICRONS\s+(\d+)\s*;", text)
    design_match = re.search(r"\bDESIGN\s+(\S+)\s*;", text)
    die_match = re.search(
        r"\bDIEAREA\s*\(\s*(-?\d+)\s+(-?\d+)\s*\)\s*"
        r"\(\s*(-?\d+)\s+(-?\d+)\s*\)\s*;",
        text,
    )
    pins_match = re.search(r"\bPINS\s+(\d+)\s*;(.*?)\bEND\s+PINS\b", text, re.S)
    if not (units_match and design_match and die_match and pins_match):
        raise ValueError(f"Unable to parse required DEF records from {path}")

    units = _number(units_match.group(1))
    pin_entries = re.findall(r"(?ms)^\s*-\s+(\S+)(.*?);\s*$", pins_match.group(2))
    pins: dict[str, dict] = {}
    for name, body in pin_entries:
        direction = re.search(r"\+\s+DIRECTION\s+(\S+)", body)
        use = re.search(r"\+\s+USE\s+(\S+)", body)
        # Organizer templates encode absolute pin rectangles with one zero-offset
        # FIXED record. OpenDB writes one PORT per rectangle, using a rectangle
        # relative to its FIXED center. Normalize both forms to absolute boxes.
        port_bodies = re.split(r"\+\s+PORT\b", body)[1:] if re.search(r"\+\s+PORT\b", body) else [body]
        absolute_shapes = []
        for port_body in port_bodies:
            placement = re.search(
                r"\+\s+(FIXED|PLACED)\s+\(\s*(-?\d+)\s+(-?\d+)\s*\)\s+(\S+)",
                port_body,
            )
            if not placement:
                raise ValueError(f"Pin {name} in {path} has geometry without placement")
            px = _number(placement.group(2))
            py = _number(placement.group(3))
            orient = placement.group(4)
            if orient != "N":
                raise ValueError(f"Unsupported pin orientation {orient} on {name} in {path}")
            for layer, x1, y1, x2, y2 in re.findall(
                r"\+\s+LAYER\s+(\S+).*?"
                r"\(\s*(-?\d+)\s+(-?\d+)\s*\)\s*"
                r"\(\s*(-?\d+)\s+(-?\d+)\s*\)",
                port_body,
                re.S,
            ):
                absolute_shapes.append(
                    {
                        "layer": layer,
                        "rect_um": [
                            (_number(x1) + px) / units,
                            (_number(y1) + py) / units,
                            (_number(x2) + px) / units,
                            (_number(y2) + py) / units,
                        ],
                    }
                )
        absolute_shapes.sort(key=lambda shape: (shape["layer"], shape["rect_um"]))
        pins[name] = {
            "direction": direction.group(1) if direction else None,
            "use": use.group(1) if use else None,
            "absolute_shapes": absolute_shapes,
        }

    return {
        "path": str(path),
        "design": design_match.group(1),
        "units": units,
        "declared_pin_count": _number(pins_match.group(1)),
        "parsed_pin_count": len(pins),
        "diearea_um": [v / units for v in map(_number, die_match.groups())],
        "pins": pins,
    }


def normalized_pin(pin: dict) -> str:
    return json.dumps(pin, sort_keys=True, separators=(",", ":"))


def compare_defs(template: dict, final: dict) -> dict:
    template_names = set(template["pins"])
    final_names = set(final["pins"])
    changed = sorted(
        name
        for name in template_names & final_names
        if normalized_pin(template["pins"][name]) != normalized_pin(final["pins"][name])
    )
    return {
        "design_matches": template["design"] == final["design"],
        "diearea_matches": template["diearea_um"] == final["diearea_um"],
        "pin_count_matches": (
            template["declared_pin_count"] == final["declared_pin_count"]
            and template["parsed_pin_count"] == final["parsed_pin_count"]
        ),
        "missing_from_final": sorted(template_names - final_names),
        "extra_in_final": sorted(final_names - template_names),
        "changed_pins": changed,
    }


def audit_gds(path: Path) -> dict:
    try:
        import pya  # type: ignore
    except ImportError as exc:
        raise RuntimeError("KLayout's pya module is required for GDS auditing") from exc

    layout = pya.Layout()
    layout.read(str(path))
    top_cells = layout.top_cells()
    if len(top_cells) != 1:
        raise ValueError(f"Expected one GDS top cell, found {len(top_cells)}")
    top = top_cells[0]
    layer_indices = [
        index
        for index in layout.layer_indices()
        if layout.get_info(index).layer == 0 and layout.get_info(index).datatype == 0
    ]
    if not layer_indices:
        layer_shapes = pya.Region()
        shape_count = 0
    else:
        layer_shapes = pya.Region()
        shape_count = 0
        for layer_index in layer_indices:
            direct_shapes = top.shapes(layer_index)
            shape_count += direct_shapes.size()
            layer_shapes.insert(direct_shapes)
    bbox = layer_shapes.bbox()
    bbox_um = None if bbox.empty() else [v * layout.dbu for v in (bbox.left, bbox.bottom, bbox.right, bbox.top)]
    return {
        "path": str(path),
        "top_cell": top.name,
        "dbu_um": layout.dbu,
        "layer_0_0_shape_count": shape_count,
        "layer_0_0_bbox_um": bbox_um,
        "layer_0_0_exact_1110_square": bbox_um == [0.0, 0.0, 1110.0, 1110.0],
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--template-def", type=Path, required=True)
    parser.add_argument("--final-def", type=Path, required=True)
    parser.add_argument("--gds", type=Path, required=True)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()

    template = parse_def(args.template_def)
    final = parse_def(args.final_def)
    comparison = compare_defs(template, final)
    gds = audit_gds(args.gds)
    passed = all(
        [
            comparison["design_matches"],
            comparison["diearea_matches"],
            comparison["pin_count_matches"],
            not comparison["missing_from_final"],
            not comparison["extra_in_final"],
            not comparison["changed_pins"],
            gds["top_cell"] == template["design"],
            gds["layer_0_0_exact_1110_square"],
        ]
    )
    result = {
        "pass": passed,
        "template_def": {k: v for k, v in template.items() if k != "pins"},
        "final_def": {k: v for k, v in final.items() if k != "pins"},
        "def_template_comparison": comparison,
        "gds": gds,
    }
    rendered = json.dumps(result, indent=2, sort_keys=True)
    print(rendered)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered + "\n", encoding="utf-8")
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())
