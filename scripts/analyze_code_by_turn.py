#!/usr/bin/env python3
"""Map Git code changes to the nearest classified AI turn."""
from __future__ import annotations

import argparse
import bisect
import collections
import datetime as dt
import json
import statistics
import subprocess
from pathlib import Path

CODE_EXTENSIONS = {"py", "tla", "cfg", "sh", "toml", "yaml", "yml"}


def parse_time(value: str) -> dt.datetime:
    return dt.datetime.fromisoformat(value.replace("Z", "+00:00"))


def is_code(path: str) -> bool:
    return not path.startswith(("docs/", "site/")) and "." in path and path.rsplit(".", 1)[1].lower() in CODE_EXTENSIONS


def git_commits(repo: Path) -> list[dict]:
    raw = subprocess.check_output(["git", "-C", str(repo), "log", "--all", "--reverse", "--date=iso-strict", "--pretty=format:COMMIT|%h|%aI|%s", "--numstat"], text=True)
    result, current = [], None
    for line in raw.splitlines():
        if line.startswith("COMMIT|"):
            if current:
                result.append(current)
            _, short, stamp, subject = line.split("|", 3)
            current = {"short": short, "timestamp": stamp, "subject": subject, "code_add": 0, "code_del": 0}
        elif line and current:
            parts = line.split("\t")
            if len(parts) >= 3 and parts[0].isdigit() and parts[1].isdigit() and is_code(parts[2]):
                current["code_add"] += int(parts[0])
                current["code_del"] += int(parts[1])
    if current:
        result.append(current)
    return result


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("phase_json", type=Path)
    ap.add_argument("--repo", type=Path, default=Path.cwd())
    ap.add_argument("--output", type=Path, required=True)
    args = ap.parse_args()
    phase_data = json.loads(args.phase_json.read_text(encoding="utf-8"))
    turns = phase_data.get("turn_sequence", [])
    turn_times = [parse_time(turn["timestamp"]) for turn in turns]
    aggregates = [{"turn_number": i + 1, "turn_id": turn["turn_id"], "timestamp": turn["timestamp"], "dominant_phase": turn["dominant_phase"], "model": turn.get("model"), "commit_count": 0, "code_add": 0, "code_del": 0, "commits": []} for i, turn in enumerate(turns)]
    unmatched = []
    for commit in git_commits(args.repo):
        if not turn_times:
            unmatched.append(commit)
            continue
        stamp = parse_time(commit["timestamp"])
        position = bisect.bisect_left(turn_times, stamp)
        candidates = [index for index in (position - 1, position) if 0 <= index < len(turn_times)]
        index = min(candidates, key=lambda candidate: abs((turn_times[candidate] - stamp).total_seconds()))
        delta = abs((turn_times[index] - stamp).total_seconds())
        row = aggregates[index]
        row["commit_count"] += 1
        row["code_add"] += commit["code_add"]
        row["code_del"] += commit["code_del"]
        row["commits"].append({"short": commit["short"], "timestamp": commit["timestamp"], "subject": commit["subject"], "code_add": commit["code_add"], "code_del": commit["code_del"], "delta_seconds": round(delta, 3)})
    code_turns = [row for row in aggregates if row["code_add"] or row["code_del"]]
    additions = [row["code_add"] for row in aggregates]
    result = {
        "schema": "ai4tla.code-by-turn.v1",
        "definition": "Each Git code change is assigned to the nearest classified turn by timestamp; this is temporal attribution, not causal proof.",
        "turn_count": len(aggregates),
        "code_change_turn_count": len(code_turns),
        "commit_count": sum(row["commit_count"] for row in aggregates),
        "unmatched_commit_count": len(unmatched),
        "summary": {"median_code_add_per_turn": statistics.median(additions) if additions else 0, "mean_code_add_per_turn": round(statistics.mean(additions), 3) if additions else 0, "zero_code_turns": sum(value == 0 for value in additions), "max_code_add_per_turn": max(additions) if additions else 0, "median_commits_per_code_turn": statistics.median(row["commit_count"] for row in code_turns) if code_turns else 0},
        "turns": aggregates,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"turns": len(aggregates), "code_change_turns": len(code_turns), "commits": result["commit_count"], "summary": result["summary"], "output": str(args.output)}, indent=2))


if __name__ == "__main__":
    main()
