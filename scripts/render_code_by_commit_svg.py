#!/usr/bin/env python3
"""Render one point/bar per code-changing commit."""
from __future__ import annotations

import argparse
import html
import json
import math
import statistics
from pathlib import Path

COLORS = {"source_audit":"#2563eb", "tla_modeling":"#7c3aed", "verification":"#16a34a", "bug_ledger":"#dc2626", "documentation":"#9333ea", "coordination":"#0f766e"}


def text(x: int, y: int, value: str, size: int = 12, fill: str = "#172033", anchor: str = "start") -> str:
    return f'<text x="{x}" y="{y}" font-family="Arial,sans-serif" font-size="{size}" fill="{fill}" text-anchor="{anchor}">{html.escape(value)}</text>'


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("data", type=Path)
    ap.add_argument("--output", type=Path, required=True)
    args = ap.parse_args()
    source = json.loads(args.data.read_text(encoding="utf-8"))
    commits = []
    for turn in source["turns"]:
        for commit in turn["commits"]:
            commits.append({**commit, "turn_number": turn["turn_number"], "phase": turn.get("dominant_phase", "source_audit")})
    values = [commit["code_add"] for commit in commits]
    maximum = max(values, default=1)
    log_max = math.log1p(maximum) or 1
    width, height = 1600, 780
    left, right, top, bottom = 110, 65, 180, 165
    plot_w, plot_h = width - left - right, height - top - bottom
    median = statistics.median(values) if values else 0
    lines = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">', '<defs><filter id="shadow" x="-10%" y="-10%" width="120%" height="120%"><feDropShadow dx="0" dy="2" stdDeviation="3" flood-opacity=".12"/></filter></defs>', '<rect width="100%" height="100%" fill="#f6f8fb"/>', '<rect x="28" y="22" width="1544" height="118" rx="16" fill="#ffffff" filter="url(#shadow)"/>', text(58, 58, "Code additions by commit", 27), text(58, 86, "One mark per commit · commits are ordered chronologically and colored by the nearest AI turn phase", 14, "#64748b"), text(58, 119, "Y-axis uses a logarithmic scale so small fixes and large model bursts remain visible", 12, "#94a3b8")]
    cards = [("COMMITS", f"{len(commits):,}"), ("MEDIAN", f"{median:g} lines"), ("ZERO-CODE", f"{sum(value == 0 for value in values):,}"), ("LARGEST", f"{maximum:,} lines")]
    for i, (label, value) in enumerate(cards):
        x = 790 + i * 185
        lines += [f'<rect x="{x}" y="42" width="166" height="70" rx="10" fill="#f8fafc" stroke="#e2e8f0"/>', text(x + 14, 64, label, 9, "#64748b"), text(x + 14, 94, value, 20, "#172033")]
    lines.append(f'<rect x="{left-22}" y="{top-22}" width="{plot_w+44}" height="{plot_h+45}" rx="12" fill="#ffffff" stroke="#e2e8f0"/>')
    for value in [0, 1, 10, 100, 1000, maximum]:
        fraction = math.log1p(value) / log_max if value else 0
        y = top + plot_h - fraction * plot_h
        lines.append(f'<line x1="{left}" y1="{y:.1f}" x2="{width-right}" y2="{y:.1f}" stroke="#dbe3ee" stroke-dasharray="3 5"/>')
        lines.append(text(left - 14, y + 4, str(value), 10, "#64748b", "end"))
    for index, commit in enumerate(commits):
        x = left + index * plot_w / max(1, len(commits) - 1)
        value = commit["code_add"]
        if value:
            bar_h = plot_h * math.log1p(value) / log_max
            y = top + plot_h - bar_h
            color = COLORS.get(commit["phase"], "#64748b")
            title = f'Commit {index+1} {commit["short"]}: +{value} lines; turn {commit["turn_number"]}; {commit["phase"]}; {commit["timestamp"]}; {commit["subject"]}'
            bar_width = max(1.0, min(4.0, plot_w / max(1, len(commits)) * 0.8))
            lines.append(f'<rect x="{x-bar_width/2:.1f}" y="{y:.1f}" width="{bar_width:.1f}" height="{bar_h:.1f}" rx="1.2" fill="{color}" fill-opacity=".86"><title>{html.escape(title)}</title></rect>')
        if index % 100 == 0:
            lines.append(f'<line x1="{x:.1f}" y1="{top+plot_h}" x2="{x:.1f}" y2="{top+plot_h+8}" stroke="#94a3b8"/>')
            lines.append(text(round(x), top + plot_h + 27, str(index + 1), 10, "#64748b", "middle"))
    lines += [text(left + plot_w / 2, top + plot_h + 53, "chronological commit number", 12, "#475569", "middle"), text(58, height - 48, f'{len(commits):,} commits · median {median:g} added lines · hover a mark for commit and turn details', 12, "#64748b")]
    legend_x, legend_y = 600, height - 45
    for i, (phase, color) in enumerate(COLORS.items()):
        x = legend_x + i * 145
        lines += [f'<rect x="{x}" y="{legend_y-10}" width="11" height="11" rx="3" fill="{color}"/>', text(x + 16, legend_y, phase, 10, "#475569")]
    lines.append("</svg>")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(args.output)


if __name__ == "__main__":
    main()
