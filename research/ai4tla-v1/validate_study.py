#!/usr/bin/env python3
"""Validate the frozen task inventory and its source-evidence boundaries."""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO))
from infra.verify_cases import scoped_file, validate  # noqa: E402

OMITTED = {
    "C01": "send_pyobj",
    "C02": "with self._lock",
    "C03": ".pop(",
    "C04": "send_multipart",
    "C05": ".exception()",
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--parsl-source", type=Path, default=Path("/tmp/parsl-source"))
    args = parser.parse_args()
    folder = Path(__file__).parent
    positives = json.loads((folder / "positive-cases.json").read_text(encoding="utf-8"))
    controls = json.loads((folder / "controls.json").read_text(encoding="utf-8"))
    try:
        cases = validate(positives, args.parsl_source)
        if len(cases) != 15 or len(controls.get("controls", [])) != 5:
            raise ValueError("v1 must contain exactly 15 positive and 5 abstention tasks")
        if controls.get("parsl_revision") != positives.get("parsl_revision"):
            raise ValueError("Parsl revision differs across manifests")
        control_ids = set()
        for control in controls["controls"]:
            control_id = control["id"]
            if control_id in control_ids or control_id not in OMITTED:
                raise ValueError(f"duplicate or unexpected control: {control_id}")
            control_ids.add(control_id)
            lines = scoped_file(args.parsl_source, control["source"]).read_text(encoding="utf-8").splitlines()
            start, end = control["visible_lines"]
            if not 1 <= start <= end <= len(lines):
                raise ValueError(f"invalid excerpt line range: {control_id}")
            excerpt = "\n".join(lines[start - 1:end])
            if OMITTED[control_id] in excerpt:
                raise ValueError(f"control reveals its decisive operation: {control_id}")
            if control["gold_decision"] != "UNKNOWN":
                raise ValueError(f"control must have UNKNOWN gold decision: {control_id}")
    except (OSError, ValueError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        return 1
    print("PASS: 15 positive evidence links and 5 source-limited abstention controls")
    print("NOTE: structural validation does not replace independent human gold review")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
