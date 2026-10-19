#!/usr/bin/env python3
"""Render a human-readable binned trend instead of one bar per commit."""
from __future__ import annotations

import argparse
import html
import json
import math
import statistics
from pathlib import Path


def text(x: int, y: int, value: str, size: int = 12, fill: str = "#172033", anchor: str = "start", weight: str = "400") -> str:
    return f'<text x="{x}" y="{y}" font-family="Arial,sans-serif" font-size="{size}" font-weight="{weight}" fill="{fill}" text-anchor="{anchor}">{html.escape(value)}</text>'


def quantile(values: list[int], fraction: float) -> float:
    if not values:
        return 0
    ordered = sorted(values)
    position = (len(ordered) - 1) * fraction
    low, high = math.floor(position), math.ceil(position)
    if low == high:
        return ordered[low]
    return ordered[low] + (ordered[high] - ordered[low]) * (position - low)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("data", type=Path)
    ap.add_argument("--output", type=Path, required=True)
    ap.add_argument("--bins", type=int, default=28)
    args = ap.parse_args()
    source = json.loads(args.data.read_text(encoding="utf-8"))
    commits = []
    for turn in source["turns"]:
        for commit in turn["commits"]:
            commits.append({**commit, "phase": turn.get("dominant_phase", "source_audit"), "turn_number": turn["turn_number"]})
    commits.sort(key=lambda row: row["timestamp"])
    bins = []
    for start in range(0, len(commits), max(1, math.ceil(len(commits) / args.bins))):
        group = commits[start:start + max(1, math.ceil(len(commits) / args.bins))]
        values = [row["code_add"] for row in group]
        bins.append({"start": start + 1, "end": start + len(group), "date": group[len(group)//2]["timestamp"][:10], "median": quantile(values, .5), "p25": quantile(values, .25), "p75": quantile(values, .75), "mean": statistics.mean(values), "total": sum(values)})
    cumulative = []
    total = 0
    for index, commit in enumerate(commits, 1):
        total += commit["code_add"] - commit["code_del"]
        if index == 1 or index % max(1, len(commits) // 100) == 0 or index == len(commits):
            cumulative.append((index, total))
    max_value = max((row["p75"] for row in bins), default=1)
    max_value = max(max_value, 1)
    max_total = max((value for _, value in cumulative), default=1)
    width, height = 1500, 900
    left, right, top, chart_bottom = 100, 70, 175, 565
    chart_w, chart_h = width - left - right, chart_bottom - top
    lines = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">', '<defs><filter id="shadow" x="-10%" y="-10%" width="120%" height="120%"><feDropShadow dx="0" dy="2" stdDeviation="3" flood-opacity=".12"/></filter></defs>', '<rect width="100%" height="100%" fill="#f6f8fb"/>', '<rect x="28" y="22" width="1444" height="122" rx="18" fill="#ffffff" filter="url(#shadow)"/>', text(58, 60, "Is AI code output shrinking?", 28, "#172033", weight="700"), text(58, 91, "A binned trend view of commit size — designed to show the signal, not every individual bar", 15, "#64748b"), text(58, 121, "Each point summarizes a chronological window of commits; the band is the 25th–75th percentile.", 12, "#94a3b8")]
    stats = [("COMMITS", f"{len(commits):,}"), ("WINDOWS", f"{len(bins)}"), ("MEDIAN COMMIT", f"{statistics.median(row['code_add'] for row in commits):g} lines"), ("LARGEST OUTLIER", f"{max(row['code_add'] for row in commits):,} lines")]
    for i, (label, value) in enumerate(stats):
        x = 820 + i * 155
        lines += [f'<rect x="{x}" y="43" width="138" height="70" rx="10" fill="#f8fafc" stroke="#e2e8f0"/>', text(x + 12, 65, label, 8, "#64748b"), text(x + 12, 95, value, 17, "#172033", weight="700")]
    lines.append(f'<rect x="{left-22}" y="{top-22}" width="{chart_w+44}" height="{chart_h+44}" rx="14" fill="#ffffff" stroke="#e2e8f0"/>')
    log_max = math.log1p(max_value)
    for value in [0, 1, 10, 100, 1000, round(max_value)]:
        fraction = math.log1p(value) / log_max if value else 0
        y = chart_bottom - fraction * chart_h
        lines += [f'<line x1="{left}" y1="{y:.1f}" x2="{width-right}" y2="{y:.1f}" stroke="#dbe3ee" stroke-dasharray="3 5"/>', text(left - 14, y + 4, str(value), 10, "#64748b", "end")]
    points = []
    for index, row in enumerate(bins):
        x = left + index * chart_w / max(1, len(bins) - 1)
        median_y = chart_bottom - math.log1p(row["median"]) / log_max * chart_h
        low_y = chart_bottom - math.log1p(row["p25"]) / log_max * chart_h
        high_y = chart_bottom - math.log1p(row["p75"]) / log_max * chart_h
        points.append((x, median_y))
        lines.append(f'<line x1="{x:.1f}" y1="{high_y:.1f}" x2="{x:.1f}" y2="{low_y:.1f}" stroke="#7c3aed" stroke-width="12" stroke-linecap="round" opacity=".18"><title>{row["date"]}: p25={row["p25"]:.1f}, median={row["median"]:.1f}, p75={row["p75"]:.1f}</title></line>')
        lines.append(text(round(x), chart_bottom + 25, row["date"][5:], 10, "#64748b", "middle"))
    lines.append('<polyline points="' + " ".join(f"{x:.1f},{y:.1f}" for x, y in points) + '" fill="none" stroke="#7c3aed" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/>')
    for index, (x, y) in enumerate(points):
        row = bins[index]
        lines.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="6" fill="#7c3aed" stroke="#fff" stroke-width="2"><title>Commits {row["start"]}–{row["end"]}: median {row["median"]:.1f} lines; mean {row["mean"]:.1f}</title></circle>')
    lines += [text(left + chart_w / 2, chart_bottom + 55, "chronological commit window", 12, "#475569", "middle"), text(40, top - 35, "Median additions / commit", 11, "#7c3aed"), text(40, chart_bottom + 34, "lower", 10, "#94a3b8")]
    # A small cumulative-size strip makes growth visible without sharing the
    # scale with commit size.
    strip_top, strip_bottom = 650, 790
    lines += [text(left, strip_top - 18, "Cumulative net code/model lines", 14, "#172033", weight="700"), text(width-right, strip_top - 18, "project size proxy", 11, "#94a3b8", "end"), f'<rect x="{left-22}" y="{strip_top}" width="{chart_w+44}" height="{strip_bottom-strip_top}" rx="14" fill="#ffffff" stroke="#e2e8f0"/>']
    cum_points = []
    for index, total in cumulative:
        x = left + (index - 1) * chart_w / max(1, len(commits) - 1)
        y = strip_bottom - (total / max_total) * (strip_bottom - strip_top - 22)
        cum_points.append((x, y))
    lines.append('<polyline points="' + " ".join(f"{x:.1f},{y:.1f}" for x, y in cum_points) + '" fill="none" stroke="#dc2626" stroke-width="3" stroke-linejoin="round"/>')
    lines.append(text(left + chart_w / 2, strip_bottom - 12, "cumulative code/model growth", 11, "#dc2626", "middle"))
    lines.append(text(58, 858, "The trend is bursty and phase-dependent: a falling median is interrupted by new model-generation bursts. It is not a monotonic complexity law.", 12, "#64748b"))
    lines.append("</svg>")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(args.output)


if __name__ == "__main__":
    main()
