#!/usr/bin/env python3
"""Render phase classification and commit alignment as a standalone HTML page."""
from __future__ import annotations

import argparse
import html
import json
from pathlib import Path

PHASES = ["source_audit", "tla_modeling", "verification", "bug_ledger", "documentation", "coordination"]
COLORS = {"source_audit":"#2563eb", "tla_modeling":"#7c3aed", "verification":"#16a34a", "bug_ledger":"#dc2626", "documentation":"#9333ea", "coordination":"#0f766e"}

def bars(values: dict[str, int]) -> str:
    maximum = max(values.values()) if values else 1
    rows = []
    for phase in PHASES:
        value = values.get(phase, 0)
        size = max(2, round(540 * value / maximum)) if value else 0
        rows.append(f'<div class="bar-row"><span class="label">{phase}</span><span class="bar" style="width:{size}px;background:{COLORS[phase]}"></span><span class="value">{value:,}</span></div>')
    return "".join(rows)

def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("analysis", type=Path)
    ap.add_argument("--output", type=Path, required=True)
    args = ap.parse_args()
    data = json.loads(args.analysis.read_text(encoding="utf-8"))
    days = data["phase_by_day"]
    day_rows = []
    for day, values in days.items():
        maximum = max(values.values()) if values else 1
        cells = []
        for phase in PHASES:
            value = values.get(phase, 0)
            opacity = 0.12 + 0.88 * value / maximum if value else 0.04
            cells.append(f'<td style="background:{COLORS[phase]};opacity:{opacity}" title="{phase}: {value}">{value}</td>')
        dominant = max(values, key=values.get)
        day_rows.append(f'<tr><th>{day}</th>{"".join(cells)}<td><b>{dominant}</b> ({sum(values.values()):,})</td></tr>')
    model_rows = []
    for model, values in data["phase_by_model"].items():
        cells = "".join(f'<td>{values.get(phase, 0):,}</td>' for phase in PHASES)
        model_rows.append(f'<tr><th>{html.escape(model)}</th>{cells}</tr>')
    commit_counts = {phase: 0 for phase in PHASES}
    for commit in data["commit_alignment"]:
        for phase in commit["nearest_phase"]:
            commit_counts[phase] += 1
    sequence = []
    last = None
    for day, values in days.items():
        phase = max(values, key=values.get)
        if phase != last:
            sequence.append((day, phase))
            last = phase
    sequence_html = " → ".join(f'<span style="color:{COLORS[p]}"><b>{d}</b> {p}</span>' for d, p in sequence)
    page = (
        '<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">'
        '<title>AI4TLA+ Research Phase Analysis</title><style>'
        'body{margin:0;background:#f8fafc;color:#172033;font:14px system-ui,sans-serif}main{max-width:1200px;margin:auto;padding:28px}'
        'h1{margin:0 0 6px}h2{margin:24px 0 12px}.muted{color:#64748b}.grid{display:grid;grid-template-columns:1fr 1fr;gap:18px}'
        'section{background:#fff;border:1px solid #e2e8f0;border-radius:12px;padding:18px}.bar-row{display:flex;align-items:center;gap:8px;margin:10px 0}'
        '.label{width:130px;font-family:ui-monospace,monospace;font-size:12px}.bar{height:15px;border-radius:5px;display:inline-block}.value{color:#475569}'
        'table{width:100%;border-collapse:collapse;font-size:12px}th,td{padding:7px;border-bottom:1px solid #e2e8f0;text-align:right}th:first-child,td:first-child{text-align:left}thead th{color:#475569}tbody td:not(:last-child){color:#fff;font-variant-numeric:tabular-nums}'
        '.sequence{line-height:2.4;background:#f1f5f9;border-radius:8px;padding:12px}code{font-family:ui-monospace,monospace}@media(max-width:800px){.grid{grid-template-columns:1fr}}'
        '</style></head><body><main><h1>AI4TLA+ Research Phase Analysis</h1>'
        '<p class="muted">Multi-label classification of exposed response text, joined to Git commit timestamps. This is a lower-bound activity signal, not a semantic transcript or causal proof.</p>'
        f'<div class="grid"><section><h2>Observed phase volume</h2>{bars(data["phase_counts"])}</section><section><h2>Nearest phase for commits</h2>{bars(commit_counts)}</section></div>'
        f'<section style="margin-top:18px"><h2>Dominant phase sequence by day</h2><div class="sequence">{sequence_html}</div></section>'
        f'<section style="margin-top:18px"><h2>Phase heatmap by day</h2><div style="overflow:auto"><table><thead><tr><th>UTC day</th>{"".join(f"<th>{p}</th>" for p in PHASES)}<th>dominant / total</th></tr></thead><tbody>{"".join(day_rows)}</tbody></table></div></section>'
        f'<section style="margin-top:18px"><h2>Phase volume by model label</h2><div style="overflow:auto"><table><thead><tr><th>model</th>{"".join(f"<th>{p}</th>" for p in PHASES)}</tr></thead><tbody>{"".join(model_rows)}</tbody></table></div></section>'
        '<p class="muted">Generated from <code>docs/ai4tla-phase-analysis.json</code> by <code>scripts/render_phase_analysis.py</code>.</p></main></body></html>'
    )
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(page, encoding="utf-8")
    print(args.output)

if __name__ == "__main__":
    main()
