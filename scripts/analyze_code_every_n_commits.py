#!/usr/bin/env python3
"""Aggregate mapped code changes into fixed-size commit windows."""
from __future__ import annotations

import argparse
import json
from pathlib import Path


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("data", type=Path)
    ap.add_argument("--size", type=int, default=20)
    ap.add_argument("--output", type=Path, required=True)
    args = ap.parse_args()
    source = json.loads(args.data.read_text(encoding="utf-8"))
    commits = []
    for turn in source["turns"]:
        for commit in turn["commits"]:
            commits.append({**commit, "turn_number": turn["turn_number"], "phase": turn.get("dominant_phase", "source_audit")})
    commits.sort(key=lambda row: row["timestamp"])
    windows = []
    cumulative = 0
    for start in range(0, len(commits), args.size):
        group = commits[start:start + args.size]
        additions = sum(row["code_add"] for row in group)
        deletions = sum(row["code_del"] for row in group)
        cumulative += additions - deletions
        windows.append({"window": len(windows) + 1, "commit_start": start + 1, "commit_end": start + len(group), "date_start": group[0]["timestamp"][:10], "date_end": group[-1]["timestamp"][:10], "code_add": additions, "code_del": deletions, "net_growth": additions - deletions, "cumulative_net_code": cumulative, "zero_code_commits": sum(row["code_add"] == 0 for row in group), "dominant_phases": sorted({row["phase"] for row in group})})
    result = {"schema": "ai4tla.code-every-n-commits.v1", "window_size": args.size, "commit_count": len(commits), "windows": windows}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"commits": len(commits), "windows": len(windows), "window_size": args.size, "output": str(args.output)}, indent=2))


if __name__ == "__main__":
    main()
