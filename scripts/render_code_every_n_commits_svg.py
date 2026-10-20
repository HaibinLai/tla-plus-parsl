#!/usr/bin/env python3
"""Render fixed-size commit-window growth as a readable SVG."""
from __future__ import annotations

import argparse
import html
import json
import math
from pathlib import Path


def text(x: int, y: int, value: str, size: int = 12, fill: str = "#172033", anchor: str = "start", weight: str = "400") -> str:
    return f'<text x="{x}" y="{y}" font-family="Arial,sans-serif" font-size="{size}" font-weight="{weight}" fill="{fill}" text-anchor="{anchor}">{html.escape(value)}</text>'


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("data", type=Path)
    ap.add_argument("--output", type=Path, required=True)
    args = ap.parse_args()
    data = json.loads(args.data.read_text(encoding="utf-8"))
    windows = data["windows"]
    maximum = max((row["code_add"] for row in windows), default=1)
    cumulative_max = max((row["cumulative_net_code"] for row in windows), default=1)
    width, height = 1500, 820
    left, right, top, chart_bottom = 100, 70, 175, 545
    chart_w, chart_h = width - left - right, chart_bottom - top
    lines = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">', '<defs><filter id="shadow" x="-10%" y="-10%" width="120%" height="120%"><feDropShadow dx="0" dy="2" stdDeviation="3" flood-opacity=".12"/></filter></defs>', '<rect width="100%" height="100%" fill="#f6f8fb"/>', '<rect x="28" y="22" width="1444" height="122" rx="18" fill="#ffffff" filter="url(#shadow)"/>', text(58, 60, f'Code growth every {data["window_size"]} commits', 28, "#172033", weight="700"), text(58, 91, "Fixed-size windows make the trend readable while preserving commit-level chronology", 15, "#64748b"), text(58, 121, "Purple bars = additions in the window · red line = cumulative net code/model lines", 12, "#94a3b8")]
    median_additions = sorted(row["code_add"] for row in windows)[len(windows) // 2] if windows else 0
    stats = [("WINDOWS", f"{len(windows):,}"), ("COMMITS", f"{data['commit_count']:,}"), ("MEDIAN ADDITIONS", f"{median_additions:,}"), ("TOTAL NET GROWTH", f"{windows[-1]['cumulative_net_code']:,}" if windows else "0")]
    for i, (label, value) in enumerate(stats):
        x = 820 + i * 155
        lines += [f'<rect x="{x}" y="43" width="138" height="70" rx="10" fill="#f8fafc" stroke="#e2e8f0"/>', text(x + 12, 65, label, 8, "#64748b"), text(x + 12, 95, value, 17, "#172033", weight="700")]
    lines.append(f'<rect x="{left-22}" y="{top-22}" width="{chart_w+44}" height="{chart_h+44}" rx="14" fill="#ffffff" stroke="#e2e8f0"/>')
    for tick in range(0, 5):
        fraction = tick / 4
        y = chart_bottom - fraction * chart_h
        value = round(maximum * fraction)
        lines += [f'<line x1="{left}" y1="{y:.1f}" x2="{width-right}" y2="{y:.1f}" stroke="#dbe3ee" stroke-dasharray="3 5"/>', text(left - 14, y + 4, f"{value:,}", 10, "#7c3aed", "end")]
    line_points = []
    for index, row in enumerate(windows):
        x = left + index * chart_w / max(1, len(windows) - 1)
        bar_h = chart_h * row["code_add"] / max(1, maximum)
        y = chart_bottom - bar_h
        bar_width = max(8, min(26, chart_w / max(1, len(windows)) * .7))
        title = f'Window {row["window"]}: commits {row["commit_start"]}–{row["commit_end"]}; +{row["code_add"]} / -{row["code_del"]}; net {row["net_growth"]}; {row["date_start"]} to {row["date_end"]}'
        lines.append(f'<rect x="{x-bar_width/2:.1f}" y="{y:.1f}" width="{bar_width:.1f}" height="{bar_h:.1f}" rx="5" fill="#7c3aed" fill-opacity=".78"><title>{html.escape(title)}</title></rect>')
        line_y = chart_bottom - chart_h * row["cumulative_net_code"] / max(1, cumulative_max)
        line_points.append((x, line_y))
        lines.append(text(round(x), chart_bottom + 25, str(row["window"]), 10, "#64748b", "middle"))
    lines.append('<polyline points="' + " ".join(f"{x:.1f},{y:.1f}" for x, y in line_points) + '" fill="none" stroke="#dc2626" stroke-width="3" stroke-linejoin="round"/>')
    for x, y in line_points:
        lines.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="3.5" fill="#dc2626"/>')
    lines += [text(left + chart_w / 2, chart_bottom + 53, "20-commit window number", 12, "#475569", "middle"), text(left, chart_bottom + 86, "Purple bars: additions (left scale)", 11, "#7c3aed"), text(width-right, chart_bottom + 86, "Red line: cumulative net code/model growth", 11, "#dc2626", "end")]
    # Add a compact table for the first/last windows so readers can connect
    # the visual to concrete commit ranges.
    table_y = 685
    lines.append(text(left, table_y, "Window examples", 14, "#172033", weight="700"))
    examples = windows[:2] + windows[-2:]
    for index, row in enumerate(examples):
        x = left + index * 335
        lines += [f'<rect x="{x}" y="{table_y+18}" width="310" height="45" rx="8" fill="#ffffff" stroke="#e2e8f0"/>', text(x + 12, table_y + 37, f'W{row["window"]} · commits {row["commit_start"]}–{row["commit_end"]}', 10, "#475569"), text(x + 12, table_y + 54, f'+{row["code_add"]:,} / -{row["code_del"]:,} · net {row["net_growth"]:,}', 11, "#172033", weight="700")]
    lines += [text(58, 795, "A window is a measurement choice: 20 commits smooths commit noise but does not prove a causal relationship with complexity.", 12, "#64748b"), "</svg>"]
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(args.output)


if __name__ == "__main__":
    main()
