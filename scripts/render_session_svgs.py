#!/usr/bin/env python3
"""Render compact, dependency-free SVG figures from sanitized activity data."""
from __future__ import annotations

import argparse
import collections
import datetime as dt
import html
import json
from pathlib import Path

PHASES = ["source_audit", "tla_modeling", "verification", "bug_ledger", "documentation", "coordination"]
CATEGORIES = ["tla", "tla_config", "runtime_probe", "bug_ledger", "documentation", "analysis_script", "other"]
PHASE_COLORS = {"source_audit":"#2563eb", "tla_modeling":"#7c3aed", "verification":"#16a34a", "bug_ledger":"#dc2626", "documentation":"#9333ea", "coordination":"#0f766e"}
CATEGORY_COLORS = {"tla":"#2563eb", "tla_config":"#60a5fa", "runtime_probe":"#16a34a", "bug_ledger":"#dc2626", "documentation":"#9333ea", "analysis_script":"#ea580c", "other":"#64748b"}


def svg_text(x: int, y: int, value: str, size: int = 12, fill: str = "#172033", anchor: str = "start") -> str:
    return f'<text x="{x}" y="{y}" font-family="Arial,sans-serif" font-size="{size}" fill="{fill}" text-anchor="{anchor}">{html.escape(value)}</text>'


def header(title: str, subtitle: str, width: int, height: int) -> list[str]:
    return [f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">', '<rect width="100%" height="100%" fill="#f8fafc"/>', svg_text(36, 38, title, 22, "#172033"), svg_text(36, 61, subtitle, 12, "#64748b")]


def write(path: Path, lines: list[str]) -> None:
    lines.append("</svg>")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def render_phase(data: dict, path: Path) -> None:
    days = data["phase_by_day"]
    width, height = 1200, 520
    lines = header("AI4TLA+ research phase heatmap", "Multi-label classification of exposed session text; counts are a lower bound, not a transcript.", width, height)
    left, top, cell_w, cell_h = 150, 105, 82, 42
    for row, phase in enumerate(PHASES):
        lines.append(svg_text(left - 12, top + row * cell_h + 26, phase, 11, "#475569", "end"))
    max_value = max((v for day in days.values() for v in day.values()), default=1)
    for col, (day, values) in enumerate(days.items()):
        x = left + col * cell_w
        lines.append(svg_text(x + cell_w / 2, top - 12, day[5:], 10, "#64748b", "middle"))
        for row, phase in enumerate(PHASES):
            value = values.get(phase, 0)
            opacity = 0.08 + 0.92 * value / max_value if value else 0.04
            y = top + row * cell_h
            lines.append(f'<rect x="{x}" y="{y}" width="{cell_w-4}" height="{cell_h-4}" rx="5" fill="{PHASE_COLORS[phase]}" fill-opacity="{opacity:.3}"/>')
            if value:
                lines.append(svg_text(x + (cell_w - 4) / 2, y + 23, str(value), 11, "#fff", "middle"))
    lines.append(svg_text(36, 430, "Interpretation", 13, "#172033"))
    lines.append(svg_text(36, 452, "The strongest activity is source auditing and verification, with concentrated bug-ledger work on Sep 29–30.", 12, "#475569"))
    lines.append(svg_text(36, 474, "A turn can count in multiple phases when it reads source, changes a model, and runs a probe together.", 12, "#475569"))
    write(path, lines)


def render_commits(data: dict, path: Path) -> None:
    width, height = 1200, 520
    lines = header("Git commit activity aligned to the Codex session", "Daily commit counts by changed-file category; exact changed paths are retained in the JSON evidence.", width, height)
    commits = data["commit_alignment"]
    daily = collections.defaultdict(collections.Counter)
    for commit in commits:
        day = commit["timestamp"][:10]
        for category, count in commit["categories"].items():
            daily[day][category] += count
    days = sorted(daily)
    left, top, chart_w, chart_h = 90, 110, 1040, 280
    max_total = max((sum(v.values()) for v in daily.values()), default=1)
    for i, day in enumerate(days):
        x = left + i * chart_w / max(1, len(days) - 1)
        lines.append(svg_text(round(x), top + chart_h + 23, day[5:], 10, "#64748b", "middle"))
        y = top + chart_h
        for category in CATEGORIES:
            value = daily[day].get(category, 0)
            h = chart_h * value / max_total
            if h:
                y -= h
                lines.append(f'<rect x="{x-13:.1f}" y="{y:.1f}" width="26" height="{h:.1f}" fill="{CATEGORY_COLORS[category]}"/>')
    for tick in range(0, 4):
        y = top + chart_h - tick * chart_h / 3
        lines.append(f'<line x1="{left-20}" y1="{y:.1f}" x2="{left+chart_w}" y2="{y:.1f}" stroke="#cbd5e1" stroke-dasharray="3 4"/>')
        lines.append(svg_text(left - 26, y + 4, str(round(max_total * tick / 3)), 10, "#64748b", "end"))
    legend_x, legend_y = 90, 465
    for i, category in enumerate(CATEGORIES):
        x = legend_x + i * 145
        lines.append(f'<rect x="{x}" y="{legend_y-11}" width="11" height="11" fill="{CATEGORY_COLORS[category]}"/>')
        lines.append(svg_text(x + 16, legend_y, category, 10, "#475569"))
    write(path, lines)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("session_json", type=Path)
    ap.add_argument("phase_json", type=Path)
    ap.add_argument("--output-dir", type=Path, required=True)
    args = ap.parse_args()
    render_commits(json.loads(args.session_json.read_text(encoding="utf-8")), args.output_dir / "session-commit-timeline.svg")
    render_phase(json.loads(args.phase_json.read_text(encoding="utf-8")), args.output_dir / "session-phase-heatmap.svg")
    print(args.output_dir / "session-commit-timeline.svg")
    print(args.output_dir / "session-phase-heatmap.svg")


if __name__ == "__main__":
    main()
