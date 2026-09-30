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
- per-inner physical retries;
- inner failure/cancellation and outer terminal failure;
- ordered successful list results.

Focused models refine boundaries that are easy to lose in a set-based abstraction:

- ParslJoinDuplicates and ParslJoinDuplicateFailureAggregation preserve list positions and
  count a failed Future once per occurrence;
- ParslJoinCallbackRace models callbacks that run before all inner Futures are terminal and
  duplicate callbacks after outer completion;
- ParslJoinRunningCancellation models cancellation after an inner attempt has entered running;
- ParslJoinReturnEquality covers user-defined equality raising during return-shape validation;
- ParslJoinRetryDuplicates combines duplicate input positions with inner physical retries.

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
