#!/usr/bin/env python3
"""Render the inferred bug-to-validation workflow as an SVG flow diagram."""
from __future__ import annotations

import argparse
import html
import json
from pathlib import Path

STAGES = ["bug_proposal", "tla_modeling", "tlc", "runtime_probe", "bug_ledger"]
COLORS = ["#dc2626", "#7c3aed", "#2563eb", "#16a34a", "#9333ea"]


def text(x: int, y: int, value: str, size: int = 12, fill: str = "#172033", anchor: str = "start", weight: str = "400") -> str:
    return f'<text x="{x}" y="{y}" font-family="Arial,sans-serif" font-size="{size}" font-weight="{weight}" fill="{fill}" text-anchor="{anchor}">{html.escape(value)}</text>'


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("data", type=Path)
    ap.add_argument("--output", type=Path, required=True)
    args = ap.parse_args()
    data = json.loads(args.data.read_text(encoding="utf-8"))
    width, height = 1450, 760
    xs = [150, 430, 710, 990, 1270]
    center_y = 320
    counts = data["stage_counts"]
    transitions = data["transition_counts"]
    max_edge = max((transitions.get(f"{left}->{right}", 0) for left, right in zip(STAGES, STAGES[1:])), default=1)
    lines = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">', '<defs><filter id="shadow" x="-10%" y="-10%" width="120%" height="120%"><feDropShadow dx="0" dy="2" stdDeviation="3" flood-opacity=".14"/></filter></defs>', '<rect width="100%" height="100%" fill="#f6f8fb"/>', '<rect x="28" y="22" width="1394" height="120" rx="18" fill="#ffffff" filter="url(#shadow)"/>', text(58, 60, "From bug proposal to validated ledger entry", 28, "#172033", weight="700"), text(58, 91, "Inferred turn-level workflow: bug → TLA+ model → TLC → runtime probe → bug ledger", 15, "#64748b"), text(58, 120, "Edges show non-decreasing stage transitions observed within adjacent classified turns", 12, "#94a3b8")]
    for index, (stage, color) in enumerate(zip(STAGES, COLORS)):
        if index < len(STAGES) - 1:
            count = transitions.get(f"{stage}->{STAGES[index+1]}", 0)
            width_edge = 3 + 14 * count / max_edge
            lines.append(f'<line x1="{xs[index]+85}" y1="{center_y}" x2="{xs[index+1]-85}" y2="{center_y}" stroke="#64748b" stroke-width="{width_edge:.1f}" opacity=".65"/>')
            lines.append(text((xs[index]+xs[index+1])//2, center_y - 18, f"{count:,}", 12, "#475569", "middle", "700"))
        lines += [f'<circle cx="{xs[index]}" cy="{center_y}" r="82" fill="{color}" filter="url(#shadow)"/>', text(xs[index], center_y - 8, stage.replace("_", " "), 14, "#fff", "middle", "700"), text(xs[index], center_y + 18, f'{counts.get(stage, 0):,} turns', 12, "#fff", "middle")]
    lines += [text(58, 525, "Complete chain detection", 17, "#172033", weight="700"), text(58, 552, f'{data["complete_chain_count"]:,} complete chains found within a maximum 50-turn span.', 13, "#475569"), text(58, 580, "A chain is counted when the ordered stage signals appear after one another; stages can overlap within one turn.", 12, "#64748b")]
    examples = data["complete_chains"][:8]
    lines.append(f'<rect x="58" y="610" width="1334" height="92" rx="12" fill="#ffffff" stroke="#e2e8f0"/>')
    for index, chain in enumerate(examples):
        x = 78 + (index % 4) * 325
        y = 640 + (index // 4) * 27
        lines.append(text(x, y, f'chain {index+1}: turns {chain["start_turn"]}→{chain["end_turn"]} ({chain["span_turns"]} span)', 11, "#475569"))
    lines.append("</svg>")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(args.output)


if __name__ == "__main__":
    main()
