#!/usr/bin/env python3
"""Generate a small, reproducible observation for the TLA+ serialization model.

The script intentionally records observations instead of hard-coding a pickle
digest: pickle bytes can change with Python and cloudpickle versions.
"""

from __future__ import annotations

import hashlib
import json
import threading
from pathlib import Path
from typing import Any, Dict

import cloudpickle

GLOBAL_FACTOR = 7
NESTED_GLOBAL = {"offset": 3}


def make_callable(default_scale: int = 2):
    closure_bias = 5

    def closure_function(value: int, scale: int = default_scale) -> int:
        return (value + closure_bias) * scale + GLOBAL_FACTOR + NESTED_GLOBAL["offset"]

    return closure_function


def make_unserializable_callable():
    lock = threading.Lock()

    def bad_function(value: int) -> int:
        with lock:
            return value

    return bad_function


def build_fixture() -> Dict[str, Any]:
    function = make_callable()
    payload = {"argument": 11, "nested": {"items": ["alpha", "beta"]}}
    encoded = cloudpickle.dumps((function, payload), protocol=4)
    restored_function, restored_payload = cloudpickle.loads(encoded)
    expected = function(payload["argument"])
    assert restored_function(payload["argument"]) == expected
    assert restored_payload == payload

    try:
        cloudpickle.dumps(make_unserializable_callable(), protocol=4)
    except Exception as exc:  # cloudpickle's concrete exception varies by version
        bad_error = type(exc).__name__
    else:
        raise AssertionError("the lock-containing callable unexpectedly serialized")

    closure_values = []
    if function.__closure__:
        closure_values = [type(cell.cell_contents).__name__ for cell in function.__closure__]

    return {
        "serializer": "cloudpickle",
        "serializer_version": getattr(cloudpickle, "__version__", "unknown"),
        "protocol": 4,
        "object_components": [
            "function",
            "globals",
            "defaults",
            "closure",
            "argument",
            "nested",
        ],
        "function_name": function.__name__,
        "has_defaults": function.__defaults__ is not None,
        "closure_cell_types": closure_values,
        "pickle_bytes": len(encoded),
        "pickle_sha256": hashlib.sha256(encoded).hexdigest(),
        "round_trip_result": expected,
        "unserializable_case": "threading.Lock in closure",
        "unserializable_error": bad_error,
    }


def main() -> None:
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    fixture = build_fixture()
    rendered = json.dumps(fixture, indent=2, sort_keys=True) + "\n"
    if args.output:
        args.output.write_text(rendered, encoding="utf-8")
    else:
        print(rendered, end="")


if __name__ == "__main__":
    main()
