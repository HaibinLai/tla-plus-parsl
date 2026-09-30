# Project Progress Log

This file is the durable project record for the TLA+ Parsl abstraction effort. Chat retention is
external to this repository, so important decisions, coverage counts, and the next audit target
are recorded here in English and committed with the model changes.

## 2026-09-30

### Current repository state

- Latest pushed commit: pending (HTEX null registration block ID refinement).
- Foundational smoke inventory: 368 TLC cases and 235 Python runtime probes.
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
- Verification stage: the complete foundational regression passed after the join refinement:
  all 362 TLC smoke cases passed with `TLC_SIMULATE=10`, and all 233 Python runtime probes
  passed against the installed Parsl source. The runtime run emitted only existing resource
  warnings from temporary Parsl log handles; no test failed.
- Current stage: added `ParslHtexCancelledFailureResult`, the failure-payload counterpart to
  `ParslHtexCancelledResult`. The current HTEX result worker can escape after `set_exception`
  rejects a cancelled Future and its recovery call rejects again; the Current model produces a
  two-state counterexample, the Fixed model passes in seven generated/four distinct states, and
  the runtime probe reproduces the stranded later failure Future.
- Current stage: added `ParslFluxLateFailureCancelledFuture`, the failure counterpart to the
  existing late-success cancellation model. `_complete_future` can call `set_exception` on a
  cancelled wrapper after an underlying Flux job fails; the Current model produces a two-state
  counterexample, the Fixed model passes in four generated/two distinct states, and the concrete
  callback probe reproduces the `InvalidStateError`.
- Current stage: bridged the existing BUG-018 failure-path models to concrete collector probes.
  Work Queue and TaskVine each now exercise a cancelled first failure report followed by a live
  report; the current collector aborts and its finalizer fails the unrelated Future, matching the
  Current TLA+ semantics. The targeted result suites pass 11/11 tests.
- Current stage: added `ParslFluxCancelRunningRace`, which models `FluxFutureWrapper.cancel()`
  while the wrapper is RUNNING but the underlying Flux future still accepts cancellation. The
  Current model produces a two-state `NoRawCancelError` counterexample, the Fixed model passes in
  four generated/two distinct states, and the runtime probe reproduces the raw `RuntimeError` plus
  the inconsistent unfinished-wrapper state.
- Current stage: added `ParslScaleInResultShape` for malformed provider cancellation responses.
  A short boolean result list currently reaches a raw `_filter_scale_in_ids` assertion; the
  Current model produces a two-state counterexample, the Fixed model passes in four generated/two
  distinct states, and the runtime probe reproduces the assertion directly.
- Current stage: added `ParslAwsInstanceStateShape` for an empty EC2 reservation in
  `AWSProvider.get_instance_state`. The Current model produces a two-state `NoRawIndexError`
  counterexample, the Fixed model passes in four generated/two distinct states, and the provider
  probe reproduces the concrete `IndexError`.
- Current stage: added `ParslHtexRegistrationBlockId` for a null manager registration block ID.
  The current interchange reaches an internal assertion after decoding the ZMQ registration;
  the Current model produces a two-state `NoRawAssertion` counterexample, the Fixed model passes
  in four generated/two distinct states, and the manager-message runtime suite now passes 6/6.

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
