#!/usr/bin/env python3
"""Create privacy-conscious activity evidence from a Codex session JSONL.

The script never writes prompt text or tool output. It emits only counts,
allow-listed repository paths, commit metadata, and timestamps.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import re
import subprocess
from collections import Counter, defaultdict
from pathlib import Path


UTC = dt.timezone.utc
SHA_RE = re.compile(r"\b[0-9a-f]{7,40}\b")


def parse_time(value: str | None) -> dt.datetime | None:
    if not value:
        return None
    try:
        return dt.datetime.fromisoformat(value.replace("Z", "+00:00")).astimezone(UTC)
    except ValueError:
        return None


def category(path: str) -> str:
    if path.startswith("models/") and path.endswith(".tla"):
        return "tla"
    if path.startswith("models/") and path.endswith(".cfg"):
        return "tla_config"
    if path.startswith("tests/") or "probe" in path.lower():
        return "runtime_probe"
    if path.startswith("docs/bugs/") or "bug-ledger" in path:
        return "bug_ledger"
    if path.startswith("docs/"):
        return "documentation"
    if path.startswith("scripts/"):
        return "analysis_script"
    return "other"


def git_commits(repo: Path) -> list[dict]:
    fmt = "%H%x1f%h%x1f%aI%x1f%s"
    raw = subprocess.check_output(
        ["git", "-C", str(repo), "log", "--all", f"--pretty=format:{fmt}", "--name-only"],
        text=True,
    )
    commits = []
    for block in raw.split("\n\n"):
        lines = [line for line in block.splitlines() if line]
        if not lines or "\x1f" not in lines[0]:
            continue
        full, short, stamp, subject = lines[0].split("\x1f", 3)
        files = lines[1:]
        commits.append({
            "full": full,
            "short": short,
            "timestamp": stamp,
            "subject": subject,
            "files": files,
            "categories": dict(Counter(category(path) for path in files)),
        })
    return commits


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("session", type=Path)
    ap.add_argument("--repo", type=Path, default=Path.cwd())
    ap.add_argument("--output", type=Path, required=True)
    args = ap.parse_args()

    counts = Counter()
    models = Counter()
    roles = Counter()
    event_types = Counter()
    content_types = Counter()
    days = Counter()
    turns = set()
    timestamps: list[dt.datetime] = []
    text_path_mentions = Counter()
    allowlisted_paths = set()
    for name in ("models", "docs", "scripts", "tests"):
        root = args.repo / name
        if root.exists():
            allowlisted_paths.update(str(p.relative_to(args.repo)) for p in root.rglob("*") if p.is_file())

    # Search only for known repository paths. Raw text is discarded immediately.
    # A single bounded regex is substantially faster than testing every path
    # against every response item in a multi-hundred-megabyte session.
    repo_path_re = re.compile(r"(?:models|docs|scripts|tests)/[A-Za-z0-9_.+\-/]+")

    with args.session.open(encoding="utf-8") as handle:
        for line in handle:
            try:
                record = json.loads(line)
            except json.JSONDecodeError:
                continue
            kind = record.get("type", "unknown")
            counts[kind] += 1
            stamp = parse_time(record.get("timestamp"))
            if stamp:
                timestamps.append(stamp)
                days[stamp.date().isoformat()] += 1
            payload = record.get("payload") or {}
            if not isinstance(payload, dict):
                continue
            if payload.get("turn_id"):
                turns.add(payload["turn_id"])
            if kind == "turn_context":
                models[payload.get("model", "unknown")] += 1
            if kind == "event_msg":
                event_types[payload.get("type", "unknown")] += 1
            if kind == "response_item":
                roles[payload.get("role", "unknown")] += 1
                content = payload.get("content")
                if isinstance(content, list):
                    for item in content:
                        if not isinstance(item, dict):
                            continue
                        content_types[item.get("type", "unknown")] += 1
                        text = item.get("text")
                        if isinstance(text, str):
                            for match in repo_path_re.finditer(text):
                                path = match.group(0).rstrip(".,:;)]}")
                                if path in allowlisted_paths:
                                    text_path_mentions[path] += 1

    commits = git_commits(args.repo)
    event_times = sorted(timestamps)
    for commit in commits:
        stamp = parse_time(commit["timestamp"])
        if stamp and event_times:
            nearest = min(event_times, key=lambda item: abs((item - stamp).total_seconds()))
            commit["nearest_session_event"] = nearest.isoformat()
            commit["nearest_event_delta_seconds"] = round(abs((nearest - stamp).total_seconds()), 3)
        commit["changed_file_count"] = len(commit["files"])
        del commit["files"]

    bug_ledger_text = ""
    canonical_ledger = args.repo / "docs" / "bug-ledger.md"
    if canonical_ledger.exists():
        bug_ledger_text = canonical_ledger.read_text(encoding="utf-8")
    bug_ids = sorted(set(re.findall(r"\bBUG-\d+\b", bug_ledger_text)))
    inventory = {
        "tla_modules": len(list((args.repo / "models").rglob("*.tla"))) if (args.repo / "models").exists() else 0,
        "tla_configs": len(list((args.repo / "models").rglob("*.cfg"))) if (args.repo / "models").exists() else 0,
        "runtime_probe_files": len(list((args.repo / "tests").glob("test_*_runtime.py"))) if (args.repo / "tests").exists() else 0,
        "bug_ledger_category_files": len(list((args.repo / "docs" / "bugs").rglob("*.md"))) if (args.repo / "docs" / "bugs").exists() else 0,
        "canonical_bug_ids": len(bug_ids),
    }

    result = {
        "schema": "ai4tla.codex-session-analysis.v1",
        "source": "local Codex session JSONL; raw text intentionally omitted",
        "time_range": {
            "first": min(timestamps).isoformat() if timestamps else None,
            "last": max(timestamps).isoformat() if timestamps else None,
        },
        "record_counts": dict(counts),
        "distinct_turn_ids": len(turns),
        "models": dict(models),
        "roles": dict(roles),
        "content_types": dict(content_types),
        "event_types": dict(event_types),
        "daily_activity": dict(sorted(days.items())),
        "artifact_inventory": inventory,
        "allowlisted_path_mentions": {
            path: {"count": count, "category": category(path)}
            for path, count in text_path_mentions.most_common()
        },
        "commit_alignment": commits,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({
        "records": sum(counts.values()),
        "turns": len(turns),
        "commits": len(commits),
        "path_mentions": sum(text_path_mentions.values()),
        "output": str(args.output),
    }, indent=2))


if __name__ == "__main__":
    main()
