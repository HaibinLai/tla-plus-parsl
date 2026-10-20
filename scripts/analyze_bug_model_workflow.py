#!/usr/bin/env python3
"""Detect the bug -> model -> TLC -> runtime -> ledger workflow in turns."""
from __future__ import annotations

import argparse
import collections
import json
import re
from pathlib import Path

STAGES = ["bug_proposal", "tla_modeling", "tlc", "runtime_probe", "bug_ledger"]
MAX_CHAIN_SPAN = 50
PATTERNS = {
    "bug_proposal": re.compile(r"(bug|issue|failure|risk|finding|counterexample|incorrect|leak|crash)", re.I),
    "tla_modeling": re.compile(r"(TLA\+|\.tla|invariant|\.cfg|model|specification|action)", re.I),
    "tlc": re.compile(r"(TLC|model checker|generated states|distinct states|smoke)", re.I),
    "runtime_probe": re.compile(r"(runtime|probe|pytest|reproduced|installed|regression)", re.I),
    "bug_ledger": re.compile(r"(bug.?ledger|BUG-\d+|bug taxonomy|ledger entry)", re.I),
}


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("session", type=Path)
    ap.add_argument("--output", type=Path, required=True)
    args = ap.parse_args()
    turns = {}
    current_turn = None
    with args.session.open(encoding="utf-8") as handle:
        for line in handle:
            try:
                record = json.loads(line)
            except json.JSONDecodeError:
                continue
            payload = record.get("payload") or {}
            if not isinstance(payload, dict):
                continue
            if record.get("type") == "turn_context":
                current_turn = payload.get("turn_id")
                if current_turn:
                    turns.setdefault(current_turn, {"turn_id": current_turn, "timestamp": record.get("timestamp"), "model": payload.get("model"), "stages": set()})
            if record.get("type") != "response_item" or current_turn not in turns:
                continue
            for item in payload.get("content", []) if isinstance(payload.get("content"), list) else []:
                if not isinstance(item, dict) or item.get("type") != "output_text":
                    continue
                text = item.get("text")
                if not isinstance(text, str):
                    continue
                for stage, pattern in PATTERNS.items():
                    if pattern.search(text):
                        turns[current_turn]["stages"].add(stage)
    ordered = [turn for turn in turns.values() if turn["stages"]]
    ordered.sort(key=lambda turn: turn.get("timestamp") or "")
    events = []
    for index, turn in enumerate(ordered, 1):
        events.append({"turn_number": index, "turn_id": turn["turn_id"], "timestamp": turn["timestamp"], "model": turn["model"], "stages": sorted(turn["stages"], key=STAGES.index)})
    stage_counts = collections.Counter(stage for event in events for stage in event["stages"])
    transition_counts = collections.Counter()
    for previous, current in zip(events, events[1:]):
        for left in previous["stages"]:
            for right in current["stages"]:
                if STAGES.index(right) >= STAGES.index(left):
                    transition_counts[f"{left}->{right}"] += 1
    chains = []
    active = None
    next_stage = 0
    for event in events:
        if active is not None and event["turn_number"] - active["start_turn"] > MAX_CHAIN_SPAN:
            active = None
            next_stage = 0
        if "bug_proposal" in event["stages"] and active is None:
            active = {"start_turn": event["turn_number"], "steps": [{"stage": "bug_proposal", "turn": event["turn_number"]}]}
            next_stage = 1
        if active is not None and next_stage < len(STAGES):
            wanted = STAGES[next_stage]
            if wanted in event["stages"] and event["turn_number"] >= active["start_turn"]:
                active["steps"].append({"stage": wanted, "turn": event["turn_number"]})
                next_stage += 1
        if active is not None and next_stage == len(STAGES):
            active["end_turn"] = event["turn_number"]
            active["span_turns"] = event["turn_number"] - active["start_turn"]
            chains.append(active)
            active = None
            next_stage = 0
    result = {"schema": "ai4tla.bug-model-workflow.v1", "stages": STAGES, "event_count": len(events), "stage_counts": dict(stage_counts), "transition_counts": dict(transition_counts), "complete_chain_count": len(chains), "complete_chains": chains, "events": events}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"events": len(events), "stage_counts": dict(stage_counts), "complete_chains": len(chains), "output": str(args.output)}, indent=2))


if __name__ == "__main__":
    main()
