#!/usr/bin/env python3
"""Validate the self-contained Chipathon submission directory."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import yaml


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("submission_root", type=Path)
    args = parser.parse_args()
    root = args.submission_root.resolve()

    info_path = root / "info.yaml"
    with info_path.open(encoding="utf-8") as stream:
        info = yaml.safe_load(stream)
    lvs_path = root / info["project"]["lvs_config"]
    with lvs_path.open(encoding="utf-8") as stream:
        lvs = json.load(stream)

    pins = info["pins"]
    names = [pin["name"] for pin in pins]
    assert len(pins) == 22, f"expected 22 pad assignments, found {len(pins)}"
    assert len(set(names)) == 22, "pad names must be unique"
    assert pins[0] == {"name": "VSS", "io_type": "ground"}, "first pad must be quiet ground"
    assert pins[1] == {"name": "VDD", "io_type": "power"}, "VDD must be paired after VSS"
    assert lvs["TOP_SOURCE"] == "A54_A"
    top_layout = lvs["TOP_LAYOUT"].replace("$TOP_SOURCE", lvs["TOP_SOURCE"])
    assert top_layout == "A54_A"

    expected_layout = root / "gds" / f"{top_layout}.gds"
    expected_netlist = root / "verilog" / f"{lvs['TOP_SOURCE']}.nl.v"
    assert expected_layout.is_file() and expected_layout.stat().st_size > 0
    assert expected_netlist.is_file() and expected_netlist.stat().st_size > 0
    assert lvs["LAYOUT_FILE"] == "$UPRJ_ROOT/gds/$TOP_LAYOUT.gds"
    assert lvs["LVS_VERILOG_FILES"] == ["$UPRJ_ROOT/verilog/A54_A.nl.v"]

    print(f"SUBMISSION CONFIG PASS: {root}")
    print(f"  pad assignments: {len(pins)} (VSS first, VDD second)")
    print(f"  layout: {expected_layout.name} ({expected_layout.stat().st_size} bytes)")
    print(f"  netlist: {expected_netlist.name} ({expected_netlist.stat().st_size} bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
