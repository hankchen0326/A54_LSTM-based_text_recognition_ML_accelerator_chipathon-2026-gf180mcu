#!/usr/bin/env python3
"""Bit-accurate golden model for the 16-lane INT8 LSTM ASIC."""

from __future__ import annotations

import argparse
import json
from dataclasses import dataclass
from pathlib import Path

SIGMOID = [34, 36, 38, 39, 41, 43, 45, 46,
           48, 50, 52, 54, 56, 58, 60, 62,
           64, 66, 68, 70, 72, 74, 76, 78,
           80, 82, 83, 85, 87, 89, 90, 92]
GATE_TANH = [-97, -94, -90, -86, -81, -76, -71, -65,
             -59, -53, -46, -39, -31, -24, -16, -8,
             0, 8, 16, 24, 31, 39, 46, 53,
             59, 65, 71, 76, 81, 86, 90, 94]
CELL_TANH = [-97, -93, -89, -85, -81, -76, -70, -65,
             -59, -52, -46, -38, -31, -24, -16, -8,
             0, 8, 16, 24, 31, 38, 46, 52,
             59, 65, 70, 76, 81, 85, 89, 93]

BASE_WEIGHTS = [
    [-81, -46, -73, 46, 0, -55, 8, 88, -1],
    [48, 70, 6, 50, -46, 59, -84, -89, 92],
    [85, 95, 30, 87, 83, 71, 60, 92, -48],
    [32, 91, 60, -58, -92, 48, -71, 66, 8],
]
BASE_BIASES = [8, -9, -10, -5]
LANE_DELTAS = [0, 1, -1, 2, -2, 3, -3, 4,
               -4, 5, -5, 6, -6, 7, -7, 8]


def sat8(value: int) -> int:
    return max(-128, min(127, value))


def lut_index(value: int, shift: int) -> int:
    return max(0, min(31, (value >> shift) + 16))


@dataclass(frozen=True)
class LaneResult:
    h: int
    c: int
    gates: tuple[int, int, int, int]


def step(inputs: list[int], h_prev: int, c_prev: int, lane: int) -> LaneResult:
    if len(inputs) != 8:
        raise ValueError("exactly eight signed INT8 inputs are required")
    if lane not in range(16):
        raise ValueError("lane must be in range 0..15")
    values = [sat8(v) for v in inputs] + [sat8(h_prev)]
    delta = LANE_DELTAS[lane]
    gates: list[int] = []
    for gate in range(4):
        bias = sat8(BASE_BIASES[gate] + delta)
        acc = bias << 7
        for coefficient, value in zip(BASE_WEIGHTS[gate], values):
            acc += sat8(coefficient + delta) * value
        index = lut_index(acc, 10)
        gates.append(GATE_TANH[index] if gate == 2 else SIGMOID[index])

    c_next = sat8((gates[0] * sat8(c_prev) >> 7) +
                  (gates[1] * gates[2] >> 7))
    tanh_c = CELL_TANH[lut_index(c_next, 3)]
    h_next = sat8(gates[3] * tanh_c >> 7)
    return LaneResult(h_next, c_next, tuple(gates))


def generate_vectors() -> dict[str, object]:
    vectors = [
        [47, -45, 36, -42, 14, 25, -22, 38],
        [-55, -26, -40, -10, -63, 46, 22, -13],
    ]
    states = [(lane - 8, 2 * lane - 15) for lane in range(16)]
    transactions = []
    for index, inputs in enumerate(vectors):
        outputs = []
        next_states = []
        for lane, (h_prev, c_prev) in enumerate(states):
            result = step(inputs, h_prev, c_prev, lane)
            outputs.append({"lane": lane, "h": result.h, "c": result.c,
                            "gates": list(result.gates)})
            next_states.append((result.h, result.c))
        transactions.append({"index": index, "inputs": inputs, "outputs": outputs})
        states = next_states
    return {
        "design": "lstm16x_top",
        "total_pin_count": 22,
        "signal_pins_per_side": 5,
        "chip_signature_hex": "A8",
        "byte_commands": {
            "00..07 + data": "load broadcast y[0..7]",
            "10..1F + data": "load lane h_prev",
            "20..2F + data": "load lane c_prev",
            "30": "start; completion response D0",
            "40..4F": "read lane h",
            "50..5F": "read lane c",
            "60": "read status",
            "A8": "read chip signature",
        },
        "arithmetic": "signed INT8, Q1.7 gates/state, arithmetic right shifts",
        "initial_states": [{"lane": lane, "h": lane - 8, "c": 2 * lane - 15}
                           for lane in range(16)],
        "transactions": transactions,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--write-vectors", type=Path,
                        help="write deterministic FPGA/testbench vectors as JSON")
    args = parser.parse_args()
    payload = generate_vectors()
    rendered = json.dumps(payload, indent=2) + "\n"
    if args.write_vectors:
        args.write_vectors.write_text(rendered, encoding="utf-8")
    else:
        print(rendered, end="")


if __name__ == "__main__":
    main()
