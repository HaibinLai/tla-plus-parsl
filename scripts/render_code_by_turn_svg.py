#!/usr/bin/env python3
"""Render per-turn code changes with turn number on the x-axis."""
from __future__ import annotations

import argparse
import html
import json
import math
from pathlib import Path

COLORS = {"source_audit":"#2563eb", "tla_modeling":"#7c3aed", "verification":"#16a34a", "bug_ledger":"#dc2626", "documentation":"#9333ea", "coordination":"#0f766e"}


def text(x: int, y: int, value: str, size: int = 12, fill: str = "#172033", anchor: str = "start") -> str:
    return f'<text x="{x}" y="{y}" font-family="Arial,sans-serif" font-size="{size}" fill="{fill}" text-anchor="{anchor}">{html.escape(value)}</text>'


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("data", type=Path)
    ap.add_argument("--output", type=Path, required=True)
    args = ap.parse_args()
    data = json.loads(args.data.read_text(encoding="utf-8"))
    turns = data["turns"]
    width, height = 1450, 620
    left, right, top, bottom = 90, 50, 105, 145
    plot_w, plot_h = width - left - right, height - top - bottom
    maximum = max((row["code_add"] for row in turns), default=1)
    log_max = math.log1p(maximum) or 1
    lines = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">', '<rect width="100%" height="100%" fill="#f8fafc"/>', text(36, 38, "Code changes by AI turn", 22), text(36, 61, "X = turn number; Y = code lines added in commits nearest to that turn (log-scaled to show small and large changes).", 12, "#64748b")]
    for tick in range(0, 4):
        fraction = tick / 3
        y = top + plot_h - fraction * plot_h
        value = round(math.expm1(log_max * fraction))
        lines.append(f'<line x1="{left}" y1="{y:.1f}" x2="{width-right}" y2="{y:.1f}" stroke="#cbd5e1" stroke-dasharray="3 4"/>')
        lines.append(text(left - 10, y + 4, str(value), 10, "#64748b", "end"))
    for index, row in enumerate(turns):
        x = left + index * plot_w / max(1, len(turns) - 1)
        value = row["code_add"]
        if value:
            bar_h = plot_h * math.log1p(value) / log_max
            y = top + plot_h - bar_h
            phase = row.get("dominant_phase", "source_audit")
            title = f'Turn {index+1}: +{value} code lines, {row["commit_count"]} commits, {phase}, {row.get("timestamp", "")}'
            lines.append(f'<rect x="{x-1.2:.1f}" y="{y:.1f}" width="2.4" height="{bar_h:.1f}" fill="{COLORS.get(phase, "#64748b")}"><title>{html.escape(title)}</title></rect>')
        if index % 100 == 0:
            lines.append(f'<line x1="{x:.1f}" y1="{top+plot_h}" x2="{x:.1f}" y2="{top+plot_h+7}" stroke="#64748b"/>')
            lines.append(text(round(x), top + plot_h + 23, str(index + 1), 10, "#64748b", "middle"))
    lines += [text(left + plot_w / 2, height - 63, "classified AI turn number", 12, "#475569", "middle"), text(36, height - 37, f'{len(turns):,} turns; {data["summary"]["zero_code_turns"]:,} turns had no mapped code additions; median = {data["summary"]["median_code_add_per_turn"]} lines/turn.', 12, "#64748b")]
    legend_x, legend_y = 90, height - 93
    for i, (phase, color) in enumerate(COLORS.items()):
        x = legend_x + i * 160
        lines.append(f'<rect x="{x}" y="{legend_y-10}" width="11" height="11" fill="{color}"/>')
        lines.append(text(x + 16, legend_y, phase, 10, "#475569"))
    lines.append("</svg>")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(args.output)


if __name__ == "__main__":
    main()
