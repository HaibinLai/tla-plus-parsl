#!/usr/bin/env python3
"""Extract technical bigrams and co-occurrence edges without exporting text."""
from __future__ import annotations

import argparse
import collections
import itertools
import json
import re
from pathlib import Path

from analyze_session_text import NOISE, STOPWORDS, TOKEN_RE


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("session", type=Path)
    ap.add_argument("--output", type=Path, required=True)
    args = ap.parse_args()
    terms = collections.Counter()
    bigrams = collections.Counter()
    documents = []
    with args.session.open(encoding="utf-8") as handle:
        for line in handle:
            try:
                record = json.loads(line)
            except json.JSONDecodeError:
                continue
            if record.get("type") != "response_item":
                continue
            payload = record.get("payload") or {}
            if not isinstance(payload, dict):
                continue
            for item in payload.get("content", []) if isinstance(payload.get("content"), list) else []:
                if not isinstance(item, dict) or item.get("type") != "output_text":
                    continue
                raw = item.get("text")
                if not isinstance(raw, str):
                    continue
                words = [word.lower() for word in TOKEN_RE.findall(raw)]
                words = [word for word in words if word not in STOPWORDS and word not in NOISE and not word.isdigit()]
                if len(words) < 2:
                    continue
                terms.update(words)
                bigrams.update(zip(words, words[1:]))
                documents.append(set(words))
    top_terms = {term for term, _ in terms.most_common(35)}
    cooccurrence = collections.Counter()
    for document in documents:
        selected = sorted(document & top_terms)
        cooccurrence.update(itertools.combinations(selected, 2))
    result = {"schema": "ai4tla.text-network.v1", "top_terms": dict(terms.most_common(100)), "bigrams": [{"source": a, "target": b, "count": count} for (a, b), count in bigrams.most_common(150)], "cooccurrence": [{"source": a, "target": b, "count": count} for (a, b), count in cooccurrence.most_common(150)], "document_count": len(documents)}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"documents": len(documents), "unique_terms": len(terms), "bigrams": len(bigrams), "cooccurrence_edges": len(cooccurrence), "output": str(args.output)}, indent=2))


if __name__ == "__main__":
    main()
