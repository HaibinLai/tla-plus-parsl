#!/usr/bin/env python3
"""Classify exposed session text into research phases without exporting text."""
from __future__ import annotations

import argparse
import collections
import datetime as dt
import json
import re
import subprocess
from pathlib import Path

UTC = dt.timezone.utc
PHASE_PATTERNS = {
    "source_audit": re.compile(r"(parsl|source|inspect|read|\.py|executor|provider|DataManager|HTEX)", re.I),
    "tla_modeling": re.compile(r"(TLA\+|\.tla|\.cfg|model|invariant|specification)", re.I),
    "verification": re.compile(r"(TLC|pytest|probe|runtime|smoke|regression|counterexample|test)", re.I),
    "bug_ledger": re.compile(r"(bug.?ledger|BUG-\d+|bug taxonomy|finding|failure scenario)", re.I),
    "documentation": re.compile(r"(README|docs/|report|paper|podcast|LaTeX|\.tex|document)", re.I),
    "coordination": re.compile(r"(agent|subagent|delegate|collaborat|handoff)", re.I),
}
AGENT_RE = re.compile(r"/root/[A-Za-z0-9_-]+")


def parse_time(value: str | None) -> dt.datetime | None:
    if not value:
        return None
    try:
        return dt.datetime.fromisoformat(value.replace("Z", "+00:00")).astimezone(UTC)
    except ValueError:
        return None


def classify(text: str) -> list[str]:
    # Multi-label classification is intentional: a single turn can, for
    # example, inspect source code and add a corresponding TLA+ model.
    return [name for name, pattern in PHASE_PATTERNS.items() if pattern.search(text)]


def git_commits(repo: Path) -> list[dict]:
    fmt = "%h%x1f%aI%x1f%s"
    raw = subprocess.check_output(
        ["git", "-C", str(repo), "log", "--all", f"--pretty=format:{fmt}"], text=True
    )
    result = []
    for line in raw.splitlines():
        if "\x1f" not in line:
            continue
        short, stamp, subject = line.split("\x1f", 2)
        result.append({"short": short, "timestamp": stamp, "subject": subject})
    return result


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("session", type=Path)
    ap.add_argument("--repo", type=Path, default=Path.cwd())
    ap.add_argument("--output", type=Path, required=True)
    args = ap.parse_args()

    phase_counts = collections.Counter()
    phase_by_day = collections.defaultdict(collections.Counter)
    phase_by_model = collections.defaultdict(collections.Counter)
    agent_by_phase = collections.defaultdict(collections.Counter)
    phase_events: list[tuple[dt.datetime, list[str], str | None]] = []
    current_model = None
    records = 0
    text_records = 0
    with args.session.open(encoding="utf-8") as handle:
        for line in handle:
            try:
                record = json.loads(line)
            except json.JSONDecodeError:
                continue
            records += 1
            payload = record.get("payload") or {}
            if not isinstance(payload, dict):
                continue
            if record.get("type") == "turn_context":
                current_model = payload.get("model")
            if record.get("type") != "response_item":
                continue
            content = payload.get("content")
            if not isinstance(content, list):
                continue
            stamp = parse_time(record.get("timestamp"))
            for item in content:
                if not isinstance(item, dict) or item.get("type") != "output_text":
                    continue
                text = item.get("text")
                if not isinstance(text, str):
                    continue
                labels = classify(text)
                if not labels or stamp is None:
                    continue
                text_records += 1
                day = stamp.date().isoformat()
                for label in labels:
                    phase_counts[label] += 1
                    phase_by_day[day][label] += 1
                    phase_by_model[current_model or "unknown"][label] += 1
                for agent in set(AGENT_RE.findall(text)):
                    for label in labels:
                        agent_by_phase[agent][label] += 1
                phase_events.append((stamp, labels, current_model))

    phase_events.sort(key=lambda item: item[0])
    commit_alignment = []
    for commit in git_commits(args.repo):
        stamp = parse_time(commit["timestamp"])
        if stamp is None or not phase_events:
            continue
        event_stamp, labels, model = min(phase_events, key=lambda item: abs((item[0] - stamp).total_seconds()))
        commit_alignment.append({
            **commit,
            "nearest_phase": labels,
            "nearest_model": model,
            "nearest_phase_event": event_stamp.isoformat(),
            "delta_seconds": round(abs((event_stamp - stamp).total_seconds()), 3),
        })

    result = {
        "schema": "ai4tla.codex-phase-analysis.v1",
        "source": "exposed output_text fields only; raw text omitted",
        "record_count": records,
        "classified_text_records": text_records,
        "phase_counts": dict(phase_counts),
        "phase_by_day": {day: dict(counts) for day, counts in sorted(phase_by_day.items())},
        "phase_by_model": {model: dict(counts) for model, counts in sorted(phase_by_model.items())},
        "agent_by_phase": {agent: dict(counts) for agent, counts in sorted(agent_by_phase.items())},
        "commit_alignment": commit_alignment,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({
        "records": records,
        "classified_text_records": text_records,
        "phases": dict(phase_counts),
        "commits": len(commit_alignment),
        "output": str(args.output),
    }, indent=2))


if __name__ == "__main__":
    main()
