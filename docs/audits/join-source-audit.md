# `join_app` source-alignment audit

This audit records the current mapping between the installed Parsl join implementation and the
executable TLA+/runtime artifacts. It is deliberately a coverage record, not a claim that the
implementation is bug-free.

Source reviewed: `/tmp/parsl-source/parsl/dataflow/dflow.py`, `handle_exec_update` at lines
347–437 and `handle_join_update` at lines 438–515 (installed source snapshot used by the runtime
probes).

| Source behavior | Abstraction | Runtime evidence | Safety/finding |
| --- | --- | --- | --- |
| A successful join body may return one `Future` | `ParslJoinApp`, `ParslJoinComplete` | `test_join_runtime.py` | Outer completion follows the one inner result |
| An empty list is an immediate join completion | `ParslJoinNoneResult`, `ParslJoinReturnShape` | `test_join_none_result_runtime.py` | Empty result is terminal and does not wait for a callback |
| A list of Futures installs one callback per list position | `ParslJoinThreeList`, `ParslJoinDuplicates` | `test_join_three_list_runtime.py`, `test_join_duplicate_failure_aggregation_runtime.py` | Ordering and duplicate positions are preserved |
| Non-Future/tuple return is rejected | `ParslJoinReturnShape` | `test_join_return_shape_runtime.py` | Invalid shape becomes a terminal `TypeError` |
| Callback waits until every list Future is done | `ParslJoinComplete`, `ParslJoinFailureAggregation` | `test_join_callback_runtime.py` | Partial completion cannot finalize the outer task |
| Inner failure becomes `JoinError` with source IDs | `ParslJoinErrorRootCause`, `ParslJoinFailureOrder` | `test_join_error_root_cause_runtime.py`, `test_join_failure_aggregation_runtime.py` | Root cause and deterministic ordering are retained |
| Inner cancellation reaches `Future.exception()` | `ParslJoinSingleCancellation`, `ParslJoinListCancellation`, `ParslJoinImmediateCancellation` | cancellation runtime probes | Current path can leak `CancelledError`; fixed models require terminal outer failure (BUG-011/012/178) |
| Body failure may retry before an inner Future exists | `ParslJoinBodyRetry`, `ParslJoinBodyRetryMonitoring` | `test_join_body_retry_runtime.py` | Retry must not install a join callback or fail the outer Future early |
| Inner tasks own their retries; join callback consumes final state | `ParslJoinRetry`, `ParslJoinRetryStaleResult`, `ParslNestedJoinRetry` | `test_join_retry_runtime.py`, `test_join_retry_stale_result_runtime.py`, `test_nested_join_retry_runtime.py` | Old physical results cannot satisfy the current generation |
| Callback runs synchronously for an already-completed inner Future | `ParslJoinImmediateCallback`, `ParslJoinImmediateMutation` | `test_join_callback_runtime.py`, `test_join_immediate_mutation_runtime.py` | Registration-time callbacks are included in the race space |
| Callback checks outer state before doing work | `ParslJoinCleanupLifecycle`, `ParslJoinCancellation` | `test_join_cleanup_lifecycle_runtime.py`, cancellation probes | Late callbacks after terminal outer state are ignored |
| Nested joins propagate list shape and retry generation | `ParslNestedJoin`, `ParslTripleNestedJoinRetryMonitoring` | `test_nested_join_retry_runtime.py` | Inner join completion remains a dependency of the outer join |
| Monitoring records join/inner terminal transitions | `ParslJoinMonitoring`, `ParslJoinMonitoringDB`, `ParslTripleNestedJoinRetryMonitoring` | monitoring join probes | Monitoring follows logical terminal state rather than a transient callback |

## Deliberate modeling boundary

The source uses `Future.exception()` and `Future.result()` directly inside
`handle_join_update`. Cancellation behavior is therefore modeled as an explicit failure path,
not hidden as an ordinary exception. The current implementation's cancellation escapes are already
tracked in BUG-011, BUG-012, and BUG-178; this audit does not create duplicate entries.

The models abstract Python locks, callback scheduling, and executor-specific worker threads as
interleavings. They do not claim to reproduce arbitrary Python memory-model behavior. New source
findings should extend the smallest matching row above or add a new cross-component model only
when the state boundary is genuinely different.

## Next source-aligned join target

The next useful refinement is to connect a list-valued join callback to stage-out/DataFuture
publication and monitoring finalization in one bounded model. Existing `ParslJoinFileStaging`,
`ParslJoinStageRetry`, and `ParslJoinMonitoringDB` cover those pieces separately; a composition
should be added only after tracing the corresponding `DataFlowKernel._add_output_deps` callback
ordering in the installed source.
