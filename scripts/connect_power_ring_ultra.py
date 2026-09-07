#!/usr/bin/env python3
"""Add the final high-current Metal5 supply rings to the A54 wrapper.

This revision keeps the organizer boundary and terminal geometry unchanged.
It replaces the earlier direct Metal2-to-Metal1 supply entry with:

* separate closed 30 um Metal5 VDD and VSS rings;
* six independent Metal2-to-Metal5 entry banks for each supply;
* short Metal4 bridges and dense Via4 banks from VDD pads to the inner ring; and
* dense Via4 matrices at both ring crossings of every vertical Metal4 stripe.

Signal routing is not modified.
"""

import sys

import odb
from openroad import Design, Tech


if len(sys.argv) != 4:
    raise SystemExit(
        "usage: connect_power_ring_ultra.py INPUT.odb OUTPUT.odb OUTPUT.def"
    )

input_odb, output_odb, output_def = sys.argv[1:]

tech = Tech()
design = Design(tech)
design.readDb(input_odb)
db = tech.getDB()
block = db.getChip().getBlock()

layers = {
    name: db.getTech().findLayer(name)
    for name in ("Metal2", "Metal3", "Metal4", "Metal5")
}
vias = {
    name: db.getTech().findVia(name)
    for name in ("Via2_HH", "Via3_HH", "Via4_HH")
}
if any(value is None for value in (*layers.values(), *vias.values())):
    raise RuntimeError("Required Metal2-Metal5 layers or vias are missing")

# OpenDB units are 2000 DBU/um.  The two rings are separated by 1.0 um,
# which is larger than the Metal5 minimum spacing (0.92 um).
#
# VSS: 30 um wide, spans 0..30 um at the outer boundary.
# VDD: 30 um wide, spans 31..61 um immediately inside VSS.
ring_specs = {
    "VSS": {
        "half_width": 30000,
        "left": 30000,
        "right": 2190000,
        "bottom": 30000,
        "top": 2190000,
    },
    "VDD": {
        "half_width": 30000,
        "left": 92000,
        "right": 2128000,
        "bottom": 92000,
        "top": 2128000,
    },
}

# A single-cut via has a 0.26 um cut and a maximum 0.19 um metal enclosure.
# A 0.56 um center pitch therefore leaves 0.30 um cut-to-cut spacing.  Via
# centers are filled only where the complete via metal enclosure fits.
via_pitch = 1120
via_enclosure = 380

# Entry stacks fit completely in the organizer's 20 um left boundary channel.
# VDD crosses the outer VSS Metal5 rail on Metal4, then rises to Metal5 only
# after clearing VSS.  This permits both supply rings to remain fully closed.
entry_x_min = 20000  # 10 um
entry_x_max = 40000  # 20 um


def centered_positions(low, high):
    """Return a dense, centered legal via-center grid for one dimension."""
    usable = high - low - 2 * via_enclosure
    if usable < 0:
        raise RuntimeError(f"Landing is too small for a via: {low}..{high}")
    count = usable // via_pitch + 1
    span = (count - 1) * via_pitch
    start = (low + high - span) // 2
    return [start + index * via_pitch for index in range(count)]


def fill_vias(swire, via, x_min, y_min, x_max, y_max, shape_type):
    """Fill a rectangular overlap with legal, explicit single-cut vias."""
    count = 0
    for x in centered_positions(x_min, x_max):
        for y in centered_positions(y_min, y_max):
            odb.dbSBox_create(swire, via, x, y, shape_type)
            count += 1
    return count


for net_name in ("VDD", "VSS"):
    net = block.findNet(net_name)
    bterm = block.findBTerm(net_name)
    if net is None or bterm is None:
        raise RuntimeError(f"Missing required power net or BTerm: {net_name}")

    swires = net.getSWires()
    if not swires:
        raise RuntimeError(f"No generated PDN special wire found for {net_name}")
    swire = swires[0]

    pin_boxes = sorted(
        [box for bpin in bterm.getBPins() for box in bpin.getBoxes()],
        key=lambda box: (box.yMin(), box.xMin()),
    )
    if len(pin_boxes) != 6:
        raise RuntimeError(
            f"Expected six {net_name} access rectangles, found {len(pin_boxes)}"
        )
    if any(box.getTechLayer().getName() != "Metal2" for box in pin_boxes):
        raise RuntimeError(f"Expected all {net_name} access rectangles on Metal2")

    # Remove only the previous left-edge Metal2/Via1 power-entry ECO.  The
    # generated core PDN and all signal routing remain untouched.
    pin_y_min = min(box.yMin() for box in pin_boxes)
    pin_y_max = max(box.yMax() for box in pin_boxes)
    removed = []
    for box in list(swire.getWires()):
        layer_name = box.getTechLayer().getName() if box.getTechLayer() else None
        via_name = (
            box.getTechVia().getName()
            if box.isVia() and box.getTechVia() is not None
            else None
        )
        in_old_entry_window = (
            box.xMin() < 100000
            and box.xMax() < 100000
            and box.yMax() >= pin_y_min
            and box.yMin() <= pin_y_max
        )
        if in_old_entry_window and (
            layer_name == "Metal2" or (via_name and via_name.startswith("Via1"))
        ):
            removed.append(box)
    for box in removed:
        odb.dbSBox_destroy(box)

    spec = ring_specs[net_name]
    half_width = spec["half_width"]

    # Closed Metal5 ring.
    for rail_x in (spec["left"], spec["right"]):
        odb.dbSBox_create(
            swire,
            layers["Metal5"],
            rail_x - half_width,
            spec["bottom"] - half_width,
            rail_x + half_width,
            spec["top"] + half_width,
            "RING",
        )
    for rail_y in (spec["bottom"], spec["top"]):
        odb.dbSBox_create(
            swire,
            layers["Metal5"],
            spec["left"] - half_width,
            rail_y - half_width,
            spec["right"] + half_width,
            rail_y + half_width,
            "RING",
        )

    # Every existing full-height Metal4 PDN stripe is tied to both horizontal
    # ring rails.  Fill the complete Metal4/Metal5 overlap with Via4 cuts.
    m4_stripes = sorted(
        [
            box
            for box in swire.getWires()
            if not box.isVia()
            and box.getTechLayer() is not None
            and box.getTechLayer().getName() == "Metal4"
            and box.yMin() == block.getDieArea().yMin()
            and box.yMax() == block.getDieArea().yMax()
        ],
        key=lambda box: box.xMin(),
    )
    if len(m4_stripes) < 2:
        raise RuntimeError(f"Expected multiple full-height Metal4 stripes on {net_name}")

    ring_via4_count = 0
    skipped_ring_crossings = 0
    ring_x_min = spec["left"] - half_width
    ring_x_max = spec["right"] + half_width
    for stripe in m4_stripes:
        overlap_x_min = max(stripe.xMin(), ring_x_min)
        overlap_x_max = min(stripe.xMax(), ring_x_max)
        if overlap_x_max - overlap_x_min < 2 * via_enclosure:
            skipped_ring_crossings += 2
            continue
        for rail_y in (spec["bottom"], spec["top"]):
            ring_via4_count += fill_vias(
                swire,
                vias["Via4_HH"],
                overlap_x_min,
                rail_y - half_width,
                overlap_x_max,
                rail_y + half_width,
                "RING",
            )

    # Six independent full-pin-height entries.  VSS rises directly through
    # Metal2/3/4 to its outer Metal5 ring.  VDD reaches the first VDD Metal4
    # stripe using a short bridge that crosses the outer VSS ring on a different
    # layer.  A dense Via4 bank is placed only inside the VDD ring, followed by
    # a short Metal5 landing.  There is no VDD/VSS same-layer crossing.
    target_stripe = m4_stripes[0]
    entry_counts = {"Via2": 0, "Via3": 0, "Via4": 0}
    for pin_box in pin_boxes:
        odb.dbSBox_create(
            swire,
            layers["Metal2"],
            pin_box.xMin(),
            pin_box.yMin(),
            entry_x_max,
            pin_box.yMax(),
            "STRIPE",
        )
        odb.dbSBox_create(
            swire,
            layers["Metal3"],
            entry_x_min,
            pin_box.yMin(),
            entry_x_max,
            pin_box.yMax(),
            "STRIPE",
        )
        metal4_x_max = entry_x_max if net_name == "VSS" else target_stripe.xMax()
        odb.dbSBox_create(
            swire,
            layers["Metal4"],
            entry_x_min,
            pin_box.yMin(),
            metal4_x_max,
            pin_box.yMax(),
            "STRIPE",
        )
        metal5_x_min = entry_x_min if net_name == "VSS" else target_stripe.xMin()
        odb.dbSBox_create(
            swire,
            layers["Metal5"],
            metal5_x_min,
            pin_box.yMin(),
            spec["left"],
            pin_box.yMax(),
            "STRIPE",
        )
        for via_key, via_name in (("Via2", "Via2_HH"), ("Via3", "Via3_HH")):
            entry_counts[via_key] += fill_vias(
                swire,
                vias[via_name],
                entry_x_min,
                pin_box.yMin(),
                entry_x_max,
                pin_box.yMax(),
                "STRIPE",
            )
        via4_x_min = entry_x_min if net_name == "VSS" else target_stripe.xMin()
        via4_x_max = entry_x_max if net_name == "VSS" else target_stripe.xMax()
        entry_counts["Via4"] += fill_vias(
            swire,
            vias["Via4_HH"],
            via4_x_min,
            pin_box.yMin(),
            via4_x_max,
            pin_box.yMax(),
            "STRIPE",
        )

    print(
        f"{net_name}: removed {len(removed)} old entry shapes; "
        f"Metal5 width={half_width / 1000:.1f}um; "
        f"ring=({spec['left']},{spec['bottom']}).."
        f"({spec['right']},{spec['top']}); "
        f"entry cuts Via2/Via3/Via4={entry_counts['Via2']}/"
        f"{entry_counts['Via3']}/{entry_counts['Via4']}; "
        f"ring Via4 cuts={ring_via4_count}; "
        f"skipped non-overlapping crossings={skipped_ring_crossings}"
    )

design.writeDb(output_odb)
design.writeDef(output_def)
