#!/usr/bin/env python3
"""Extract privacy-conscious technical term statistics from session text."""
from __future__ import annotations

import argparse
import collections
import datetime as dt
import json
import re
from pathlib import Path

from classify_codex_activity import classify

TOKEN_RE = re.compile(r"[A-Za-z][A-Za-z0-9_+.-]{2,}")
STOPWORDS = set("""
the and for with from that this have has was were are can not but into then than
also only just about after before when where what which while will would should
could into over under between each every more most some any all one two use used
using make made get got need needs want try tried see look like looks here there
their they them our your you we i it its as is be to of in on at by or an a do
does did if so no yes not true false none return output input result error state
function value values line lines file files code run running command call called
``""".split())
NOISE = set("""
http https json python pytest stdout stderr bash shell system user assistant
response message content text type name path string integer boolean dictionary
noneclass self args kwargs print import from return def elif else for while
``""".split())


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("session", type=Path)
    ap.add_argument("--output", type=Path, required=True)
    args = ap.parse_args()
    global_counts = collections.Counter()
    phase_counts = collections.defaultdict(collections.Counter)
    day_counts = collections.defaultdict(collections.Counter)
    classified_records = 0
    with args.session.open(encoding="utf-8") as handle:
        for line in handle:
            try:
                record = json.loads(line)
            except json.JSONDecodeError:
                continue
            if record.get("type") != "response_item":
                continue
            payload = record.get("payload") or {}
            if not isinstance(payload, dict) or payload.get("role") not in ("assistant", "user"):
                continue
            content = payload.get("content")
            if not isinstance(content, list):
                continue
            timestamp = record.get("timestamp", "")[:10]
            for item in content:
                if not isinstance(item, dict) or item.get("type") != "output_text":
                    continue
                text = item.get("text")
                if not isinstance(text, str):
                    continue
                terms = [token.lower() for token in TOKEN_RE.findall(text)]
                terms = [term for term in terms if term not in STOPWORDS and term not in NOISE and not term.isdigit()]
                if not terms:
                    continue
                labels = classify(text)
                if labels:
                    classified_records += 1
                counts = collections.Counter(terms)
                global_counts.update(counts)
                for label in labels:
                    phase_counts[label].update(counts)
                if timestamp:
                    day_counts[timestamp].update(counts)
    top_terms = [term for term, _ in global_counts.most_common(60)]
    result = {
        "schema": "ai4tla.session-text-analysis.v1",
        "source": "exposed output_text fields; raw text omitted",
        "classified_text_records": classified_records,
        "global_terms": dict(global_counts.most_common(200)),
        "phase_terms": {phase: dict(counts.most_common(100)) for phase, counts in phase_counts.items()},
        "daily_terms": {day: dict(counts.most_common(80)) for day, counts in sorted(day_counts.items())},
        "top_terms": top_terms,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"classified_text_records": classified_records, "unique_terms": len(global_counts), "top_terms": top_terms[:20], "output": str(args.output)}, indent=2))


if __name__ == "__main__":
    main()
