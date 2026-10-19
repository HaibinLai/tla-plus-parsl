#!/usr/bin/env python3
"""Render the sanitized session-analysis JSON as a standalone HTML dashboard."""
from __future__ import annotations

import argparse
import collections
import html
import json
from pathlib import Path


COLORS = {
    "tla": "#2563eb",
    "tla_config": "#60a5fa",
    "runtime_probe": "#16a34a",
    "bug_ledger": "#dc2626",
    "documentation": "#9333ea",
    "analysis_script": "#ea580c",
    "other": "#64748b",
}


def bar_rows(values: dict[str, int], width: int = 520) -> str:
    maximum = max(values.values()) if values else 1
    rows = []
    for key, value in sorted(values.items(), key=lambda item: -item[1]):
        w = max(2, round(width * value / maximum))
        color = COLORS.get(key, "#64748b")
        rows.append(
            f'<div class="bar-row"><span class="label">{html.escape(key)}</span>'
            f'<span class="bar" style="width:{w}px;background:{color}"></span>'
            f'<span class="value">{value:,}</span></div>'
        )
    return "\n".join(rows)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("analysis", type=Path)
    ap.add_argument("--output", type=Path, required=True)
    args = ap.parse_args()
    data = json.loads(args.analysis.read_text(encoding="utf-8"))
    commit_categories = collections.Counter()
    for commit in data["commit_alignment"]:
        for key, value in commit["categories"].items():
            commit_categories[key] += value
    daily = data["daily_activity"]
    max_day = max(daily.values()) if daily else 1
    daily_rows = []
    for day, value in daily.items():
        height = max(4, round(180 * value / max_day))
        daily_rows.append(
            f'<div class="day"><div class="day-bar" style="height:{height}px" title="{day}: {value:,} records"></div>'
            f'<span>{html.escape(day[5:])}</span></div>'
        )
    commits = [c for c in data["commit_alignment"] if c.get("nearest_event_delta_seconds") is not None]
    commit_rows = []
    for commit in commits[:80]:
        cats = ", ".join(f"{k}:{v}" for k, v in commit["categories"].items())
        commit_rows.append(
            f'<tr><td>{html.escape(commit["timestamp"][:16].replace("T", " "))}</td>'
            f'<td><code>{commit["short"]}</code></td><td>{html.escape(commit["subject"])}</td>'
            f'<td>{html.escape(cats)}</td><td>{commit["nearest_event_delta_seconds"]:.3f}s</td></tr>'
        )
    agent_rows = "".join(
        f'<div class="bar-row"><span class="label">{html.escape(agent.rsplit("/", 1)[-1])}</span>'
        f'<span class="bar" style="width:{max(2, count * 8)}px;background:#0f766e"></span>'
        f'<span class="value">{count:,}</span></div>'
        for agent, count in data.get("agent_mentions", {}).items()
    )
    cards = [
        ("JSONL records", f'{sum(data["record_counts"].values()):,}'),
        ("Distinct turns", f'{data["distinct_turn_ids"]:,}'),
        ("Compactions", f'{data["record_counts"].get("compacted", 0):,}'),
        ("Commits aligned", f'{len(commits):,}'),
    ]
    card_html = "".join(f'<div class="card"><b>{html.escape(k)}</b><strong>{v}</strong></div>' for k, v in cards)
    page = f'''<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>AI4TLA+ Session Activity</title>
<style>
body{{margin:0;background:#f8fafc;color:#172033;font:15px system-ui,-apple-system,sans-serif}}
main{{max-width:1180px;margin:0 auto;padding:28px}} h1{{margin:0 0 6px}} h2{{margin-top:30px}}
.muted{{color:#64748b}} .cards{{display:grid;grid-template-columns:repeat(4,1fr);gap:12px;margin:24px 0}}
.card{{background:#fff;border:1px solid #e2e8f0;border-radius:12px;padding:16px;box-shadow:0 1px 2px #00000008}}
.card b{{display:block;color:#64748b;font-size:12px;text-transform:uppercase}} .card strong{{display:block;font-size:28px;margin-top:5px}}
.grid{{display:grid;grid-template-columns:1fr 1fr;gap:20px}} section{{background:#fff;border:1px solid #e2e8f0;border-radius:12px;padding:18px}}
.bar-row{{display:flex;align-items:center;gap:8px;margin:9px 0}} .label{{width:125px;font-family:ui-monospace,monospace;font-size:12px}}
.bar{{height:14px;border-radius:5px;display:inline-block}} .value{{font-variant-numeric:tabular-nums;color:#475569}}
.chart{{height:220px;display:flex;align-items:end;gap:5px;border-bottom:1px solid #cbd5e1;padding:8px 4px 0}}
.day{{height:205px;display:flex;flex-direction:column;justify-content:end;align-items:center;gap:5px;font-size:10px;color:#64748b}}
.day-bar{{width:22px;background:#2563eb;border-radius:4px 4px 0 0;min-height:4px}} table{{width:100%;border-collapse:collapse;font-size:12px}}
th,td{{padding:8px;border-bottom:1px solid #e2e8f0;text-align:left;vertical-align:top}} th{{color:#475569}} code{{font-family:ui-monospace,monospace}}
.scroll{{max-height:480px;overflow:auto}} @media(max-width:800px){{.grid{{grid-template-columns:1fr}}.cards{{grid-template-columns:repeat(2,1fr)}}}}
</style></head><body><main>
<h1>AI4TLA+ Codex Session Activity</h1>
<p class="muted">Sanitized alignment of the local session with repository commits and project artifacts. No prompt text or raw tool output is embedded.</p>
<div class="cards">{card_html}</div>
<div class="grid"><section><h2>Commit file categories</h2>{bar_rows(dict(commit_categories))}</section>
<section><h2>Session records by day</h2><div class="chart">{"".join(daily_rows)}</div></section></div>
<div class="grid" style="margin-top:20px"><section><h2>Agent mentions</h2><p class="muted">Names observed in exposed response text; this is a lower bound, not a complete delegation count.</p>{agent_rows}</section>
<section><h2>Artifact inventory</h2>{bar_rows(data.get("artifact_inventory", {}))}</section></div>
<section style="margin-top:20px"><h2>Commit ↔ session alignment</h2>
<p class="muted">The delta is the distance from each commit timestamp to the nearest recorded session event. This is temporal evidence, not proof that one specific turn caused the commit.</p>
<div class="scroll"><table><thead><tr><th>UTC</th><th>Commit</th><th>Subject</th><th>Changed categories</th><th>Nearest event</th></tr></thead><tbody>{"".join(commit_rows)}</tbody></table></div></section>
<p class="muted">Generated from <code>docs/ai4tla-session-analysis.json</code> by <code>scripts/render_session_analysis.py</code>.</p>
</main></body></html>'''
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(page, encoding="utf-8")
    print(args.output)


if __name__ == "__main__":
    main()
