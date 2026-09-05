#!/usr/bin/env python3
"""Connect the organizer DEF's multi-shape VDD/VSS BTerms to the core PDN.

Each organizer supply terminal has six Metal2 access rectangles.  Every
rectangle receives an independent, wide Metal2 branch to a distinct Metal1
followpin rail.  Four legal two-cut Via1 arrays are placed on every branch.
This avoids making the entire macro current pass through one narrow branch and
one cut while preserving the organizer-specified pin geometry.
"""

import sys

import odb
from openroad import Design, Tech


if len(sys.argv) != 4:
    raise SystemExit("usage: connect_template_power.py INPUT.odb OUTPUT.odb OUTPUT.def")

input_odb, output_odb, output_def = sys.argv[1:]

tech = Tech()
design = Design(tech)
design.readDb(input_odb)
db = tech.getDB()
block = db.getChip().getBlock()
metal1 = db.getTech().findLayer("Metal1")
metal2 = db.getTech().findLayer("Metal2")
via1 = db.getTech().findVia("Via1_2CUT_H")

if metal1 is None or metal2 is None or via1 is None:
    raise RuntimeError(
        "Required GF180 Metal1/Metal2/Via1_2CUT_H definitions were not found"
    )

# Coordinates below are OpenDB units (2000 DBU/um in this design).
# A 2.0-um branch fits comfortably inside every 9.5-10.25-um organizer
# supply access rectangle.  Four two-cut arrays provide eight cuts per branch.
branch_half_width = 2000
via_array_count = 4
via_array_pitch = 3000
via_edge_inset = 1200

for net_name in ("VDD", "VSS"):
    net = block.findNet(net_name)
    bterm = block.findBTerm(net_name)
    if net is None or bterm is None:
        raise RuntimeError(f"Missing required power net or BTerm: {net_name}")

    pin_boxes = sorted(
        [box for bpin in bterm.getBPins() for box in bpin.getBoxes()],
        key=lambda box: (box.yMin(), box.xMin()),
    )
    if len(pin_boxes) != 6:
        raise RuntimeError(f"Expected six organizer access shapes on {net_name}, found {len(pin_boxes)}")

    x_min = min(box.xMin() for box in pin_boxes)
    x_max = max(box.xMax() for box in pin_boxes)
    y_min = min(box.yMin() for box in pin_boxes)
    y_max = max(box.yMax() for box in pin_boxes)

    swires = net.getSWires()
    if not swires:
        raise RuntimeError(f"No generated PDN special wire found for {net_name}")
    swire = swires[0]

    rail_boxes = [
        box
        for box in swire.getWires()
        if not box.isVia()
        and box.getTechLayer() is not None
        and box.getTechLayer().getName() == "Metal1"
    ]
    if not rail_boxes:
        raise RuntimeError(f"No Metal1 standard-cell rails found for {net_name}")

    # Make the operation idempotent and remove the legacy single-branch ECO
    # when an earlier compatible seed is used as input.  Generated PDN shapes
    # outside this small left-edge Metal2/Via1 window are left untouched.
    legacy_boxes = []
    for box in list(swire.getWires()):
        overlaps_supply_window = box.yMax() >= y_min and box.yMin() <= y_max
        inside_left_edge_window = box.xMin() < 100000 and box.xMax() < 100000
        if not (overlaps_supply_window and inside_left_edge_window):
            continue
        if box.isVia():
            tech_via = box.getTechVia()
            if tech_via is not None and tech_via.getName().startswith("Via1"):
                legacy_boxes.append(box)
        elif (
            box.getTechLayer() is not None
            and box.getTechLayer().getName() == "Metal2"
        ):
            legacy_boxes.append(box)
    for box in legacy_boxes:
        odb.dbSBox.destroy(box)

    # Join all six access rectangles into one continuous same-net Metal2 bar.
    odb.dbSBox_create(swire, metal2, x_min, y_min, x_max, y_max, "STRIPE")

    # Connect every organizer access rectangle to a different same-net rail.
    # Prefer a rail whose center lies inside that access rectangle, then the
    # nearest unused rail if numerical grid alignment leaves none inside.
    used_rail_ys = set()
    branch_records = []
    for pin_box in pin_boxes:
        pin_center_y = (pin_box.yMin() + pin_box.yMax()) // 2

        def rail_key(rail):
            rail_y = (rail.yMin() + rail.yMax()) // 2
            inside = pin_box.yMin() <= rail_y <= pin_box.yMax()
            return (not inside, abs(rail_y - pin_center_y))

        rail = next(
            candidate
            for candidate in sorted(rail_boxes, key=rail_key)
            if (candidate.yMin() + candidate.yMax()) // 2 not in used_rail_ys
        )
        rail_y = (rail.yMin() + rail.yMax()) // 2
        used_rail_ys.add(rail_y)

        first_via_x = rail.xMin() + via_edge_inset
        via_xs = [
            first_via_x + index * via_array_pitch
            for index in range(via_array_count)
        ]
        branch_x_max = via_xs[-1] + via_edge_inset

        odb.dbSBox_create(
            swire,
            metal2,
            x_min,
            rail_y - branch_half_width,
            branch_x_max,
            rail_y + branch_half_width,
            "STRIPE",
        )
        for via_x in via_xs:
            odb.dbSBox_create(swire, via1, via_x, rail_y, "STRIPE")

        branch_records.append((rail_y, via_xs))

    print(
        f"Connected {net_name}: {len(branch_records)} parallel 2.0-um Metal2 "
        f"branches, {len(branch_records) * via_array_count} Via1_2CUT_H arrays "
        f"({len(branch_records) * via_array_count * 2} cuts), "
        f"removed {len(legacy_boxes)} legacy shapes, "
        f"rail centers={[record[0] for record in branch_records]}"
    )

design.writeDb(output_odb)
design.writeDef(output_def)
