#!/usr/bin/env python3
import sys

from openroad import Design, Tech


tech = Tech()
design = Design(tech)
design.readDb(sys.argv[1])
block = tech.getDB().getChip().getBlock()

print("logical BTerms", len(block.getBTerms()))
for bterm_name in ("VDD", "VSS"):
    bterm = block.findBTerm(bterm_name)
    print(bterm_name, "BPin access ports", len(bterm.getBPins()))

print("tech vias", [via.getName() for via in tech.getDB().getTech().getVias() if "Via1" in via.getName()])

for net_name in ("VDD", "VSS"):
    net = block.findNet(net_name)
    print(net_name, "swires", len(net.getSWires()))
    all_boxes = [box for swire in net.getSWires() for box in swire.getWires()]
    strong_vias = [
        box
        for box in all_boxes
        if box.isVia()
        and box.getTechVia() is not None
        and box.getTechVia().getName() == "Via1_2CUT_H"
    ]
    print(net_name, "Via1_2CUT_H arrays", len(strong_vias), "cut count", 2 * len(strong_vias))
    for swire_index, swire in enumerate(net.getSWires()[:2]):
        boxes = swire.getWires()
        print(" swire", swire_index, "type", swire.getWireType(), "boxes", len(boxes))
        for box in boxes[:5]:
            print(
                "  ",
                type(box).__name__,
                box.getTechLayer().getName() if box.getTechLayer() else "VIA",
                box.xMin(), box.yMin(), box.xMax(), box.yMax(),
                box.getWireShapeType(),
            )
        vias = [box for box in boxes if box.isVia()]
        if vias:
            via = vias[0]
            print(" first via methods", [name for name in dir(via) if "Via" in name])
            print(" first via bbox", via.xMin(), via.yMin(), via.xMax(), via.yMax(), via.getWireShapeType())
            if via.getTechVia() is not None:
                print(" first via name", via.getTechVia().getName())
            if via.getBlockVia() is not None:
                print(" first block via name", via.getBlockVia().getName())
