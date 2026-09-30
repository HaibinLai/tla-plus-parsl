# Project Progress Log

This file is the durable project record for the TLA+ Parsl abstraction effort. Chat retention is
external to this repository, so important decisions, coverage counts, and the next audit target
are recorded here in English and committed with the model changes.

## 2026-09-30

### Current repository state

- Latest pushed commit: `9f9b4c1` (`Model poller executor failure isolation`).
- Foundational smoke inventory: 353 TLC cases and 224 Python runtime probes (including the
  uncommitted monitoring internal-queue drain stage documented in the current working tree).
- The smoke inventory has been expanded across core dataflow, Futures, retries, stale results,
  ZMQ/serialization, callable snapshots, file bytes and staging, clocks/heartbeats/timeouts,
  monitoring persistence, executors, providers, schedulers, scaling, memoization, and `join_app`.
- The bug ledger records source/runtime findings separately from candidate fixed semantics. Current
  and fixed configurations are intentionally kept where a TLC counterexample documents the source
  behavior.

### Latest completed stages

- `e9503ff`: PBS Pro status-batch isolation. A malformed scheduler record must not prevent an
  independent valid record in the same response from being processed.
- `27a9e65`: monitoring worker cross-table atomicity. A committed `STATUS` write must not remain
  visible after the corresponding `TRY` update fails.
- `aab331c`: HTEX malformed-task continuation. A malformed task envelope must not stop the ZMQ
  ingress loop before a later valid task is queued.
- `656c5e7`: Globus token-schema validation. An incomplete cached service mapping must not expose
  a raw `KeyError` during authorizer construction.
- `b8c3e41`: Globus initialization race. Concurrent creation of `~/.parsl` must not turn ready
  directory state into `FileExistsError`.
- `00c18d9`: HTEX serialization-failure normalization. Non-`TypeError` serializer failures must
  not escape the public submit boundary as raw implementation exceptions.
- `7692d96`: recorded the HTEX serialization stage and its durable smoke inventory.
- `270d093`: refined HTEX result decoding with a corrupt-then-valid batch sequence; a bad frame
  must not strand the later Future.
- `9f9b4c1`: JobStatusPoller executor isolation. A provider/status failure in one executor must
  not suppress independent executors in the same polling tick.

### Verification convention

Each stage is checked with a Current TLC configuration, a Fixed TLC configuration, and a targeted
runtime probe against the installed Parsl source when the boundary is concrete. The full smoke
runner is a bounded regression gate; it is not an exhaustive proof of all Parsl implementation
states.

### Next audit direction

Continue source-aligned refinement of executor/provider details and `join_app` composition. Prefer
new cross-layer models that connect logical Futures, physical attempts, transport/staging events,
and monitoring records rather than duplicating an existing single-boundary model.

## Scope note

The repository preserves the implementation artifacts and project decisions. It does not claim to
archive the external chat transcript or control platform-level conversation retention.
