#!/usr/bin/env python3
"""Render top technical terms and a phase-term heatmap as SVG."""
from __future__ import annotations

import argparse
import html
import json
import math
from pathlib import Path

PHASES = ["source_audit", "tla_modeling", "verification", "bug_ledger", "documentation", "coordination"]
COLORS = {"source_audit":"#2563eb", "tla_modeling":"#7c3aed", "verification":"#16a34a", "bug_ledger":"#dc2626", "documentation":"#9333ea", "coordination":"#0f766e"}


def text(x: int, y: int, value: str, size: int = 12, fill: str = "#172033", anchor: str = "start", weight: str = "400") -> str:
    return f'<text x="{x}" y="{y}" font-family="Arial,sans-serif" font-size="{size}" font-weight="{weight}" fill="{fill}" text-anchor="{anchor}">{html.escape(value)}</text>'


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("data", type=Path)
    ap.add_argument("--output", type=Path, required=True)
    args = ap.parse_args()
    data = json.loads(args.data.read_text(encoding="utf-8"))
    terms = data["top_terms"][:24]
    global_counts = data["global_terms"]
    phase_counts = data["phase_terms"]
    phase_totals = {phase: sum(phase_counts.get(phase, {}).values()) for phase in PHASES}
    max_term = max((global_counts.get(term, 0) for term in terms), default=1)
    max_rate = 1e-9
    rates = {}
    for term in terms:
        rates[term] = {}
        for phase in PHASES:
            rate = phase_counts.get(phase, {}).get(term, 0) / max(1, phase_totals[phase]) * 10000
            rates[term][phase] = rate
            max_rate = max(max_rate, rate)
    width, height = 1500, 1050
    lines = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">', '<defs><filter id="shadow" x="-10%" y="-10%" width="120%" height="120%"><feDropShadow dx="0" dy="2" stdDeviation="3" flood-opacity=".12"/></filter></defs>', '<rect width="100%" height="100%" fill="#f6f8fb"/>', '<rect x="28" y="22" width="1444" height="120" rx="18" fill="#ffffff" filter="url(#shadow)"/>', text(58, 60, "What did the AI talk about?", 28, "#172033", weight="700"), text(58, 91, "Technical term frequency from exposed session text — filtered and aggregated without exporting the transcript", 15, "#64748b"), text(58, 120, "Left: global frequency · Right: phase-normalized term heatmap", 12, "#94a3b8")]
    # Global term bars.
    x0, y0, bar_w, row_h = 90, 190, 430, 29
    lines += [f'<rect x="50" y="160" width="560" height="790" rx="14" fill="#ffffff" stroke="#e2e8f0"/>', text(78, 194, "Top technical terms", 16, "#172033", weight="700")]
    for index, term in enumerate(terms):
        y = y0 + index * row_h
        value = global_counts.get(term, 0)
        width_px = max(2, bar_w * value / max_term)
        lines += [text(x0 - 8, y + 13, term, 11, "#475569", "end"), f'<rect x="{x0}" y="{y}" width="{width_px:.1f}" height="16" rx="4" fill="#2563eb" fill-opacity=".78"><title>{html.escape(term)}: {value:,}</title></rect>', text(x0 + width_px + 8, y + 13, f"{value:,}", 10, "#64748b")]
    # Heatmap.
    hx, hy, cell_w, cell_h = 760, 215, 105, 28
    lines += [f'<rect x="650" y="160" width="800" height="790" rx="14" fill="#ffffff" stroke="#e2e8f0"/>', text(680, 194, "Where terms occur", 16, "#172033", weight="700")]
    for col, phase in enumerate(PHASES):
        x = hx + col * cell_w
        lines.append(text(x + cell_w / 2, hy - 18, phase.replace("_", " "), 10, COLORS[phase], "middle"))
    for row, term in enumerate(terms):
        y = hy + row * cell_h
        lines.append(text(hx - 16, y + 18, term, 10, "#475569", "end"))
        for col, phase in enumerate(PHASES):
            value = rates[term][phase]
            opacity = 0.05 + 0.95 * math.sqrt(value / max_rate) if value else 0.03
            x = hx + col * cell_w
            lines += [f'<rect x="{x}" y="{y}" width="{cell_w-5}" height="{cell_h-4}" rx="4" fill="{COLORS[phase]}" fill-opacity="{opacity:.3}"><title>{html.escape(phase)} / {html.escape(term)}: {value:.2f} per 10k classified terms</title></rect>', text(x + (cell_w - 5) / 2, y + 17, f"{value:.1f}", 9, "#fff", "middle")]
    lines += [text(58, 988, "Counts are descriptive: frequent terms can reflect task vocabulary, not necessarily importance or quality.", 12, "#64748b"), "</svg>"]
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(args.output)


if __name__ == "__main__":
    main()
