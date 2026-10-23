#!/usr/bin/env python3
"""Validate and execute a small source -> TLC -> runtime evidence manifest."""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
REQUIRED = {"id", "source", "source_symbol", "model", "current_cfg", "fixed_cfg", "invariant", "probe"}
VIOLATION = re.compile(r"Error: Invariant ([A-Za-z_][A-Za-z0-9_]*) is violated\.")
SUCCESS = "Model checking completed. No error has been found."


def scoped_file(root: Path, relative: str) -> Path:
    candidate = (root / relative).resolve()
    if not candidate.is_relative_to(root.resolve()) or not candidate.is_file():
        raise ValueError(f"missing or out-of-scope file: {relative}")
    return candidate


def validate(manifest: dict, parsl_source: Path) -> list[dict]:
    if manifest.get("schema") != "ai4tla.evidence-cases.v1":
        raise ValueError("unsupported manifest schema")
    revision = subprocess.check_output(["git", "-C", str(parsl_source), "rev-parse", "HEAD"], text=True).strip()
    if revision != manifest.get("parsl_revision"):
        raise ValueError(f"Parsl revision mismatch: expected {manifest.get('parsl_revision')}, got {revision}")
    ledger = scoped_file(REPO, "docs/bug-ledger.md").read_text(encoding="utf-8")
    seen: set[str] = set()
    for case in manifest.get("cases", []):
        missing = REQUIRED - case.keys()
        if missing:
            raise ValueError(f"case missing fields: {sorted(missing)}")
        case_id = case["id"]
        if case_id in seen or not re.fullmatch(r"BUG-\d{3}", case_id):
            raise ValueError(f"duplicate or invalid case ID: {case_id}")
        seen.add(case_id)
        ledger_row = next((line for line in ledger.splitlines() if line.startswith(f"| {case_id} |")), None)
        if ledger_row is None:
            raise ValueError(f"case missing from canonical bug ledger: {case_id}")
        if Path(case["model"]).stem not in ledger_row or case["probe"] not in ledger_row:
            raise ValueError(f"ledger evidence differs from manifest: {case_id}")
        source = scoped_file(parsl_source, case["source"])
        source_text = source.read_text(encoding="utf-8")
        symbol = case["source_symbol"].split(".")[-1]
        if not re.search(rf"\bdef\s+{re.escape(symbol)}\s*\(", source_text):
            raise ValueError(f"source symbol missing: {case_id} {case['source_symbol']}")
        model = scoped_file(REPO, case["model"])
        if not re.search(rf"\b{re.escape(case['invariant'])}\s*==", model.read_text(encoding="utf-8")):
            raise ValueError(f"model invariant missing: {case_id} {case['invariant']}")
        for key in ("current_cfg", "fixed_cfg"):
            cfg = scoped_file(REPO, case[key])
            cfg_text = cfg.read_text(encoding="utf-8")
            if case["invariant"] not in cfg_text:
                raise ValueError(f"configuration omits invariant: {case_id} {key}")
        scoped_file(REPO, case["probe"])
    return manifest["cases"]


def run_tlc(java: Path, jar: Path, model: Path, cfg: Path, expected: str, invariant: str, timeout: int) -> dict:
    with tempfile.TemporaryDirectory(prefix="ai4tla-tlc-") as temp:
        command = [str(java), "-cp", str(jar), "tlc2.TLC", "-workers", "1", "-metadir", str(Path(temp) / "states"), "-config", str(cfg), str(model)]
        try:
            proc = subprocess.run(command, cwd=REPO, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=timeout)
        except subprocess.TimeoutExpired:
            return {"status": "fail", "reason": "timeout", "expected": expected}
        violations = VIOLATION.findall(proc.stdout)
        if expected == "counterexample":
            good = proc.returncode != 0 and violations == [invariant] and "The behavior up to this point is:" in proc.stdout
        else:
            good = proc.returncode == 0 and SUCCESS in proc.stdout and not violations
        return {"status": "pass" if good else "fail", "expected": expected, "exit_code": proc.returncode, "violations": violations, "states": re.findall(r"(\d+) states generated", proc.stdout)[-1:]}


def run_probe(python: Path, probe: Path, parsl_source: Path, timeout: int) -> dict:
    env = os.environ.copy()
    env["PYTHONPATH"] = str(parsl_source) + os.pathsep + env.get("PYTHONPATH", "")
    try:
        proc = subprocess.run([str(python), str(probe)], cwd=REPO, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=timeout)
    except subprocess.TimeoutExpired:
        return {"status": "fail", "reason": "timeout"}
    return {"status": "pass" if proc.returncode == 0 else "fail", "exit_code": proc.returncode, "summary": proc.stdout.strip().splitlines()[-1:]}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=Path, default=REPO / "infra/communication-cases.json")
    parser.add_argument("--parsl-source", type=Path, default=Path("/tmp/parsl-source"))
    parser.add_argument("--java", type=Path)
    parser.add_argument("--tla-jar", type=Path)
    parser.add_argument("--python", type=Path, default=Path(sys.executable))
    parser.add_argument("--timeout", type=int, default=60)
    parser.add_argument("--validate-only", action="store_true")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    try:
        manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
        cases = validate(manifest, args.parsl_source)
        if args.validate_only:
            print(f"PASS: {len(cases)} cases have linked source, model, configurations, probe, and ledger entry")
            return 0
        if not args.java or not args.tla_jar or not args.java.is_file() or not args.tla_jar.is_file():
            raise ValueError("--java and --tla-jar must name existing files")
        results = []
        for case in cases:
            model = scoped_file(REPO, case["model"])
            current = run_tlc(args.java, args.tla_jar, model, scoped_file(REPO, case["current_cfg"]), "counterexample", case["invariant"], args.timeout)
            fixed = run_tlc(args.java, args.tla_jar, model, scoped_file(REPO, case["fixed_cfg"]), "no_error", case["invariant"], args.timeout)
            probe = run_probe(args.python, scoped_file(REPO, case["probe"]), args.parsl_source, args.timeout)
            result = {"id": case["id"], "current": current, "fixed": fixed, "probe": probe}
            results.append(result)
            print(f"{case['id']}: current={current['status']} fixed={fixed['status']} probe={probe['status']}")
        report = {"schema": "ai4tla.evidence-result.v1", "parsl_revision": manifest["parsl_revision"], "results": results}
        if args.output:
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        return 0 if all(part["status"] == "pass" for result in results for part in (result["current"], result["fixed"], result["probe"])) else 1
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
