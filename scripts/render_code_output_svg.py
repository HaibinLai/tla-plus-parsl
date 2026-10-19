#!/usr/bin/env python3
"""Render code-output trend data as a two-axis SVG."""
from __future__ import annotations

import argparse
import html
import json
from pathlib import Path


def text(x: int, y: int, value: str, size: int = 12, fill: str = "#172033", anchor: str = "start") -> str:
    return f'<text x="{x}" y="{y}" font-family="Arial,sans-serif" font-size="{size}" fill="{fill}" text-anchor="{anchor}">{html.escape(value)}</text>'


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("data", type=Path)
    ap.add_argument("--output", type=Path, required=True)
    args = ap.parse_args()
    rows = json.loads(args.data.read_text(encoding="utf-8"))["daily"]
    width, height = 1200, 560
    left, right, top, bottom = 90, 90, 105, 125
    plot_w, plot_h = width - left - right, height - top - bottom
    max_median = max((row["median_code_add"] for row in rows), default=1) or 1
    max_cum = max((row["cumulative_net_code_lines"] for row in rows), default=1) or 1
    lines = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">', '<rect width="100%" height="100%" fill="#f8fafc"/>', text(36, 38, "AI coding output vs cumulative project size", 22), text(36, 61, "Bars = median code additions per commit; line = cumulative net non-documentation code/model lines.", 12, "#64748b")]
    points = []
    for i, row in enumerate(rows):
        x = left + i * plot_w / max(1, len(rows) - 1)
        bar_h = plot_h * row["median_code_add"] / max_median
        y = top + plot_h - bar_h
        lines.append(f'<rect x="{x-18:.1f}" y="{y:.1f}" width="36" height="{bar_h:.1f}" rx="4" fill="#7c3aed" fill-opacity=".78"><title>{html.escape(row["day"])} median additions: {row["median_code_add"]}</title></rect>')
        line_y = top + plot_h - plot_h * row["cumulative_net_code_lines"] / max_cum
        points.append((x, line_y))
        lines.append(text(round(x), top + plot_h + 23, row["day"][5:], 10, "#64748b", "middle"))
    lines.append('<polyline points="' + " ".join(f"{x:.1f},{y:.1f}" for x, y in points) + '" fill="none" stroke="#dc2626" stroke-width="3"/>')
    for x, y in points:
        lines.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="4" fill="#dc2626"/>')
    for tick in range(4):
        y = top + plot_h - tick * plot_h / 3
        lines.append(f'<line x1="{left}" y1="{y:.1f}" x2="{width-right}" y2="{y:.1f}" stroke="#cbd5e1" stroke-dasharray="3 4"/>')
        lines.append(text(left - 10, y + 4, str(round(max_median * tick / 3)), 10, "#7c3aed", "end"))
        lines.append(text(width - right + 10, y + 4, str(round(max_cum * tick / 3)), 10, "#dc2626"))
    lines += [text(left, height - 63, "Left axis: median code additions per commit", 11, "#7c3aed"), text(width-right, height - 63, "Right axis: cumulative net code/model lines", 11, "#dc2626", "end"), text(36, height - 36, "This is a phase-sensitive proxy, not a direct measure of model intelligence or software complexity.", 12, "#64748b"), "</svg>"]
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(args.output)


if __name__ == "__main__":
    main()
