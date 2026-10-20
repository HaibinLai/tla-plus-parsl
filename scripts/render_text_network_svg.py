#!/usr/bin/env python3
"""Render a compact technical-term co-occurrence network as SVG."""
from __future__ import annotations

import argparse
import html
import json
import math
from pathlib import Path


def text(x: int, y: int, value: str, size: int = 12, fill: str = "#172033", anchor: str = "start", weight: str = "400") -> str:
    return f'<text x="{x:.1f}" y="{y:.1f}" font-family="Arial,sans-serif" font-size="{size}" font-weight="{weight}" fill="{fill}" text-anchor="{anchor}">{html.escape(value)}</text>'


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("data", type=Path)
    ap.add_argument("--output", type=Path, required=True)
    args = ap.parse_args()
    data = json.loads(args.data.read_text(encoding="utf-8"))
    edges = data["cooccurrence"]
    degree = {}
    for edge in edges:
        degree[edge["source"]] = degree.get(edge["source"], 0) + edge["count"]
        degree[edge["target"]] = degree.get(edge["target"], 0) + edge["count"]
    nodes = [node for node, _ in sorted(degree.items(), key=lambda item: item[1], reverse=True)[:22]]
    node_set = set(nodes)
    edges = [edge for edge in edges if edge["source"] in node_set and edge["target"] in node_set][:70]
    width, height = 1500, 950
    center_x, center_y, radius = 760, 510, 320
    positions = {node: (center_x + radius * math.cos(2 * math.pi * i / len(nodes) - math.pi / 2), center_y + radius * math.sin(2 * math.pi * i / len(nodes) - math.pi / 2)) for i, node in enumerate(nodes)}
    max_edge = max((edge["count"] for edge in edges), default=1)
    max_degree = max(degree.values(), default=1)
    lines = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">', '<defs><filter id="shadow" x="-20%" y="-20%" width="140%" height="140%"><feDropShadow dx="0" dy="2" stdDeviation="3" flood-opacity=".14"/></filter></defs>', '<rect width="100%" height="100%" fill="#f6f8fb"/>', '<rect x="28" y="22" width="1444" height="112" rx="18" fill="#ffffff" filter="url(#shadow)"/>', text(58, 59, "Technical term co-occurrence network", 28, "#172033", weight="700"), text(58, 90, "Edges connect terms appearing in the same exposed AI output; line width indicates co-occurrence frequency", 15, "#64748b"), text(58, 117, "This is a vocabulary map, not a causal or semantic graph", 12, "#94a3b8")]
    for edge in edges:
        x1, y1 = positions[edge["source"]]
        x2, y2 = positions[edge["target"]]
        width_edge = 1 + 6 * edge["count"] / max_edge
        opacity = .14 + .72 * edge["count"] / max_edge
        title = f'{edge["source"]} + {edge["target"]}: {edge["count"]} co-occurrences'
        lines.append(f'<line x1="{x1:.1f}" y1="{y1:.1f}" x2="{x2:.1f}" y2="{y2:.1f}" stroke="#64748b" stroke-width="{width_edge:.2f}" opacity="{opacity:.2f}"><title>{html.escape(title)}</title></line>')
    for node in nodes:
        x, y = positions[node]
        size = 18 + 22 * degree[node] / max_degree
        lines += [f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{size:.1f}" fill="#2563eb" fill-opacity=".9" stroke="#fff" stroke-width="3" filter="url(#shadow)"><title>{html.escape(node)}: degree score {degree[node]:,}</title></circle>', text(x, y + 5, node, 12 if len(node) < 12 else 10, "#fff", "middle", "700")]
    lines += [f'<rect x="58" y="180" width="275" height="600" rx="14" fill="#ffffff" stroke="#e2e8f0"/>', text(84, 218, "Strongest observed links", 16, "#172033", weight="700")]
    for index, edge in enumerate(edges[:16]):
        y = 252 + index * 30
        lines += [text(84, y, f'{edge["source"]}  ↔  {edge["target"]}', 11, "#475569"), text(310, y, f'{edge["count"]:,}', 11, "#2563eb", "end", "700")]
    lines += [text(58, 850, f'{len(nodes)} terms · {len(edges)} displayed edges · source documents: {data["document_count"]:,}', 12, "#64748b"), "</svg>"]
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(args.output)


if __name__ == "__main__":
    main()
