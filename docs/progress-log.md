# Project Progress Log

This file is the durable project record for the TLA+ Parsl abstraction effort. Chat retention is
external to this repository, so important decisions, coverage counts, and the next audit target
are recorded here in English and committed with the model changes.

## 2026-09-30

### Current repository state

- Latest pushed commit: `d84d7d2` (`Model partial join cancellation ordering`).
- Foundational smoke inventory: 362 TLC cases and 233 Python runtime probes.
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
- `1cc300f`: monitoring internal-queue drain. Shutdown must not exit the database loop while a
  pending internal message remains after a stale `empty()` observation.
- `af476ac`: ThreadPoolExecutor empty resource-spec validation. A falsy non-mapping resource
  specification must not bypass executor input validation.
- `0f6ccec`: HTEX callable-object serialization errors. A callable without `__name__` must not
  mask the original serialization TypeError with an `AttributeError`.
- `7178406`: extended the callable-object serialization-error refinement to Flux, confirming the
  same safe error-reporting condition across two concrete executors.
- Current stage: refined BUG-018 for TaskVine and Work Queue failure reports. A cancelled Future
  can raise from `set_exception` just as it can from `set_result`; both current models produce a
  two-state counterexample, while both fixed models complete in seven generated/four distinct
  states. Runtime probes exercise both collector branches.
- Current stage: refined BUG-135 for Radical-Pilot late `FAILED` callbacks. A callback arriving
  after cancellation can raise through `set_exception` just like the existing `DONE` path; the
  failure Current model produces a four-state counterexample and the Fixed model passes.
- Current stage: added MPI malformed-result cleanup. A corrupt pickle currently escapes
  `MPITaskScheduler.get_result`, leaving allocated nodes held while the ferry loop continues;
  the Current model produces a two-state leak counterexample and the Fixed model releases the
  allocation while publishing a terminal decode failure.
- Current stage: completed the provider ledger mapping for Slurm cancellation. Existing
  `ParslSlurmCancel` and `ParslSlurmCancelBatch` models plus the runtime probe document that a
  successful remote `scancel` can still raise on a stale local ID after partially updating a
  batch; this is now tracked as BUG-277.
- Current stage: refined BUG-084 for truthy user equality. An invalid join return whose
  `__eq__([])` returns `True` enters the empty-list branch and leaves the outer Future pending;
  the new Current model has a three-state counterexample and the Fixed model passes.
- Current stage: added `ParslJoinPartialCancellation`, which forces one list member to be
  observed successfully before a second member is cancelled. The Current model produces an
  eight-state/5-distinct callback-escape counterexample; the Fixed model passes in 10/5 states.

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

For continuity, treat this file as the durable handoff point: after each meaningful stage, update
the latest commit, verification counts, completed work, and next audit direction before pushing.
