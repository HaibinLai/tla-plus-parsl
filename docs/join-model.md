# join_app model map

The join abstraction separates the outer logical task from the inner Futures and from each
inner Future's physical execution attempts. This is necessary because an inner Future can retry,
complete, fail, or be cancelled independently while the outer task remains in the joining state.

## Source-to-model mapping

| Parsl source path | Model coverage |
| --- | --- |
| parsl/dataflow/dflow.py::handle_exec_update | transition from the join body result to outer joining, invalid-return failure, and callback registration |
| parsl/dataflow/dflow.py::handle_join_update | all-inner-terminal check, callback lock, result construction, and terminal outer Future |
| parsl/dataflow/errors.py::JoinError | failure aggregation and dependent exception identifiers |
| parsl/app/app.py::join_app | outer task marked as a join task and inner Future/list return shape |
| AppFuture cancellation paths | running-inner cancellation and late callback handling |

## Model layers

The integrated ParslJoinFull model covers:

- one inner Future;
- an ordered list of Futures;
- an empty list;
- invalid join-body returns;
- duplicate list references;
- explicit callable serialization and `queued -> received -> decoded` transport stages before each
  physical attempt starts;
- per-inner physical retries;
- late completion from an older failed attempt, classified as stale in the fixed branch;
- terminal outer status emission and persistence into the monitoring database;
- bounded monitoring database-write failure and retry before terminal persistence;
- inner failure/cancellation and outer terminal failure;
- explicit outer cancellation with a terminal JoinError result and ignored later callbacks;
- ordered successful list results.

Focused models refine boundaries that are easy to lose in a set-based abstraction:

- `ParslJoinCallableTransport` connects serialized callable/object snapshots to retry generations,
  rejects obsolete physical-attempt results, and reconstructs duplicate input positions in order.
  Its runtime bridge is `tests/test_join_callable_transport_runtime.py`.
- `ParslJoinImmediateCallback` models `add_done_callback` invoking immediately for an already
  completed inner Future. The outer join enters `joining` and installs its callback gate before
  registration, so the early callback cannot finalize until every inner Future is terminal.
  `tests/test_join_callback_runtime.py` exercises the corresponding `handle_join_update` path.

- ParslJoinDuplicates and ParslJoinDuplicateFailureAggregation preserve list positions and
  count a failed Future once per occurrence;
- ParslJoinCallbackRace models callbacks that run before all inner Futures are terminal and
  duplicate callbacks after outer completion;
- ParslJoinRunningCancellation models cancellation after an inner attempt has entered running;
- ParslJoinReturnEquality covers user-defined equality raising during return-shape validation;
- ParslJoinReturnEqualityTruthy covers an invalid object whose equality with `[]` returns true;
- ParslJoinPartialCancellation covers cancellation after a prior list member has already been
  observed successfully;
- ParslJoinRetryDuplicates combines duplicate input positions with inner physical retries.
- ParslJoinRetryCancellation combines an inner non-final retry, cancellation during the retry
  window, and a late callback. The current branch reproduces the installed behavior where
  `CancelledError` escapes callback handling and leaves the outer join pending; the fixed branch
  treats cancellation as terminal inner failure and finalizes the outer join. This is the
  composition boundary between retry bookkeeping and `handle_join_update` cancellation handling.

ParslNestedJoinFailure adds explicit nested error payloads. Failed leaf IDs remain in the nested
JoinError in input order, while the outer join records the nested Future as one dependency entry.
This matches handle_join_update: the nested JoinError is the exception attached to the outer
Future, while its dependent exception identifiers retain the leaf causes. TLC checks the
failure-shape and completion invariants over 100,001 simulated states.

ParslJoinCallbackMultiplicity preserves callback multiplicity for a duplicate list such as
I1, I1, I2. The source registers one callback per list position, so completion of I1 schedules
two callback invocations. The model keeps those invocations in a sequence and checks that they
preserve both result positions while only one invocation finalizes the outer Future.

The outer callback lock is represented as an atomic callback section. A callback that observes
an incomplete list returns without finalizing; the callback for the last terminal Future performs
the all-done check and either constructs the ordered result or aggregates all failures.

`ParslJoinTimedMonitoring.tla` provides the compact clock boundary for this family: heartbeat
expiry and task timeout can lose the inner Future while its physical attempt remains capable of a
late completion. Two staged chunks must be received and published before the inner Future can
start, and a corrupt received chunk must be repaired before fixed-branch publication. The model
also lets the source version change while stage-in is incomplete: the fixed branch rejects a
captured version that is no longer current. Repairs are bounded per chunk. The current branch can
publish corrupt or stale-source content and accepts the late completion; the fixed branch rejects
those publication paths, keeps a cancelled outer join terminal, and records late completion as
stale before the outer join status is persisted. Monitoring writes can fail a bounded number of
times while the status remains queued; `DatabaseRetryBound` proves the retry counter is bounded.
The focused cancellation configurations expose the current resurrection counterexample
independently of the content-integrity counterexample.

## Safety properties

- an outer join handle remains live while the outer task is joining;
- outer success requires every joined logical Future to be terminal and successful;
- outer failure includes every failed/cancelled joined Future required by the list shape;
- duplicate references preserve both result positions and failure multiplicity;
- a running inner cancellation cannot leave the outer Future pending after its callback;
- a callback after outer termination is ignored and cannot rewrite the terminal result.

The current/fixed configurations intentionally preserve source/runtime counterexamples for
callback cancellation and return equality. The fixed variants provide the candidate terminal
handling expected by the safety properties.

`ParslNestedJoinRetry.tla` combines nested join propagation with leaf retries and late results.
Two leaf Futures feed an inner join, which feeds an outer join; an old leaf result arriving after
a retry cannot resolve the leaf or allow either join to report success in the fixed branch. TLC
checks 100,001 simulated states.
`tests/test_nested_join_retry_runtime.py` provides the corresponding live bridge: a leaf fails
once, retries, and the outer nested join waits for the inner join's final ordered result.

`ParslTripleNestedJoin.tla` extends the dependency graph to three levels: leaves A/B feed J1,
J1 plus leaf C feed J2, and J2 feeds the root. The current branch permits J2 to evaluate with
only one input terminal; the fixed branch enforces both-input gating before propagating success or
failure.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslTripleNestedJoinCurrent.cfg models/dataflow/ParslTripleNestedJoin.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslTripleNestedJoinFixed.cfg models/dataflow/ParslTripleNestedJoin.tla
```

`ParslJoinThreeList.tla` extends ordered list aggregation to three distinct inner Futures and
four list positions, including a duplicate reference. Completion callbacks may arrive in any
order, but the outer result is released only after all distinct Futures are terminal. The runtime
probe `tests/test_join_three_list_runtime.py` drives the real `handle_join_update` callback and
checks the `[third, first, second, first]` result order.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslJoinThreeList.cfg models/dataflow/ParslJoinThreeList.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_join_three_list_runtime.py -v
```

`ParslJoinThreeCancellation.tla` applies the cancellation boundary to a three-element join list.
The current branch lets `CancelledError` escape from the callback and leaves the outer task in
`joining`; the fixed branch maps the cancelled inner Future to terminal outer failure. The
runtime bridge is `test_join_list_cancellation_runtime.py`.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslJoinThreeCancellationCurrent.cfg models/dataflow/ParslJoinThreeCancellation.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslJoinThreeCancellationFixed.cfg models/dataflow/ParslJoinThreeCancellation.tla
```
