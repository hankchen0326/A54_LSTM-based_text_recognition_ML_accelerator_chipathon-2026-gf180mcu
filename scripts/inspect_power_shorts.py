#!/usr/bin/env python3
"""Find physical contacts between different special-wire power nets."""

import collections
import sys

from openroad import Design, Tech


if len(sys.argv) != 2:
    raise SystemExit("usage: inspect_power_shorts.py INPUT.odb")

tech = Tech()
design = Design(tech)
design.readDb(sys.argv[1])
block = tech.getDB().getChip().getBlock()


def touches(a, b):
    return (
        a[0] <= b[2]
        and b[0] <= a[2]
        and a[1] <= b[3]
        and b[1] <= a[3]
    )


def metal_shapes(net_name):
    result = collections.defaultdict(list)
    for swire in block.findNet(net_name).getSWires():
        for box in swire.getWires():
            if box.isVia():
                via = box.getTechVia()
                if via is None:
                    via = box.getBlockVia()
                if via is None:
                    print("unresolved via", net_name, box.xMin(), box.yMin())
                    continue
                # A placed-via SBox reports its absolute lower-left/upper-right
                # bounding box.  Recover the placement center from that box and
                # the via master's total bounding box, then expand every master
                # metal rectangle to absolute coordinates.
                master_boxes = list(via.getBoxes())
                master_x_min = min(item.xMin() for item in master_boxes)
                master_y_min = min(item.yMin() for item in master_boxes)
                master_x_max = max(item.xMax() for item in master_boxes)
                master_y_max = max(item.yMax() for item in master_boxes)
                place_x = box.xMin() - master_x_min
                place_y = box.yMin() - master_y_min
                if box.xMax() - master_x_max != place_x or box.yMax() - master_y_max != place_y:
                    print("unexpected via bbox", net_name, via.getName(), box.xMin(), box.yMin(), box.xMax(), box.yMax())
                for item in master_boxes:
                    layer = item.getTechLayer()
                    if layer is None or layer.getRoutingLevel() <= 0:
                        continue
                    result[layer.getName()].append(
                        (
                            item.xMin() + place_x,
                            item.yMin() + place_y,
                            item.xMax() + place_x,
                            item.yMax() + place_y,
                            f"via {via.getName()}",
                        )
                    )
            else:
                layer = box.getTechLayer()
                if layer is not None and layer.getRoutingLevel() > 0:
                    result[layer.getName()].append(
                        (box.xMin(), box.yMin(), box.xMax(), box.yMax(), "wire")
                    )
    return result


vdd = metal_shapes("VDD")
vss = metal_shapes("VSS")
for layer_name in sorted(set(vdd) | set(vss)):
    collisions = []
    for left in vdd[layer_name]:
        for right in vss[layer_name]:
            if touches(left, right):
                collisions.append((left, right))
                if len(collisions) >= 30:
                    break
        if len(collisions) >= 30:
            break
    print(
        layer_name,
        "VDD", len(vdd[layer_name]),
        "VSS", len(vss[layer_name]),
        "contacts", len(collisions),
    )
    for left, right in collisions:
        print(" VDD", left, "VSS", right)
