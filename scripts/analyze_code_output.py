#!/usr/bin/env python3
"""Measure commit-level code output and cumulative model/code growth."""
from __future__ import annotations

import argparse
import collections
import datetime as dt
import json
import statistics
import subprocess
from pathlib import Path

CODE_EXTENSIONS = {"py", "tla", "cfg", "sh", "toml", "yaml", "yml"}


def is_code(path: str) -> bool:
    if path.startswith(("docs/", "site/")):
        return False
    return "." in path and path.rsplit(".", 1)[1].lower() in CODE_EXTENSIONS


def collect(repo: Path) -> list[dict]:
    raw = subprocess.check_output(
        ["git", "-C", str(repo), "log", "--all", "--reverse", "--date=iso-strict", "--pretty=format:COMMIT|%h|%aI|%s", "--numstat"],
        text=True,
    )
    commits = []
    current = None
    for line in raw.splitlines():
        if line.startswith("COMMIT|"):
            if current:
                commits.append(current)
            _, short, timestamp, subject = line.split("|", 3)
            current = {"short": short, "timestamp": timestamp, "day": timestamp[:10], "subject": subject, "code_add": 0, "code_del": 0, "all_add": 0, "all_del": 0}
        elif line and current:
            parts = line.split("\t")
            if len(parts) >= 3 and parts[0].isdigit() and parts[1].isdigit():
                additions, deletions, path = int(parts[0]), int(parts[1]), parts[2]
                current["all_add"] += additions
                current["all_del"] += deletions
                if is_code(path):
                    current["code_add"] += additions
                    current["code_del"] += deletions
    if current:
        commits.append(current)
    return commits


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", type=Path, default=Path.cwd())
    ap.add_argument("--phase-json", type=Path)
    ap.add_argument("--output", type=Path, required=True)
    args = ap.parse_args()
    commits = collect(args.repo)
    cumulative = 0
    daily = []
    for day in sorted({commit["day"] for commit in commits}):
        rows = [commit for commit in commits if commit["day"] == day]
        for row in rows:
            cumulative += row["code_add"] - row["code_del"]
        values = [row["code_add"] for row in rows]
        daily.append({"day": day, "commits": len(rows), "code_add": sum(values), "code_del": sum(row["code_del"] for row in rows), "median_code_add": statistics.median(values), "mean_code_add": round(statistics.mean(values), 3), "zero_code_commits": sum(value == 0 for value in values), "cumulative_net_code_lines": cumulative})
    if args.phase_json and args.phase_json.exists():
        phase_data = json.loads(args.phase_json.read_text(encoding="utf-8"))
        turns_by_day = collections.Counter(turn["timestamp"][:10] for turn in phase_data.get("turn_sequence", []))
        for row in daily:
            row["classified_turns"] = turns_by_day[row["day"]]
            row["code_add_per_classified_turn"] = round(row["code_add"] / row["classified_turns"], 3) if row["classified_turns"] else None
    result = {"schema": "ai4tla.code-output-analysis.v1", "definition": "code means non-doc Python/TLA+/CFG/shell/config files; generated artifacts are excluded", "daily": daily, "commit_count": len(commits)}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"commits": len(commits), "days": len(daily), "output": str(args.output)}, indent=2))


if __name__ == "__main__":
    main()
