# Dataflow, Future, Join, retry, and memoization models

These models cover DataFuture propagation and cancellation, dependency traversal, Future
projection and timeout, Join semantics, callback races, nested joins, retry budgets, memoization,
resource admission, and result races.

Files live in [`models/dataflow/`](../models/dataflow/).

`ParslDependencyFailurePropagation.tla` models the ordinary DAG failure boundary.  The dependent
logical task remains blocked until its upstream Future is terminal.  A failed upstream is unwrapped
as `DependencyError`, so the current Parsl `launch_if_ready`/`handle_exec_update` path completes
the dependent task as `dep_fail` without submitting a physical attempt or consuming retry budget.
The Current configuration intentionally omits that special case and TLC finds the retry/launch
counterexample; the Fixed configuration checks dependency safety, no launch after dependency
failure, retry bounds, and terminal Future consistency.  The runtime bridge is
`tests/test_dependency_runtime.py`, which verifies both successful result propagation and that a
failed producer prevents the consumer function from executing.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslDependencyFailurePropagationCurrent.cfg models/dataflow/ParslDependencyFailurePropagation.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslDependencyFailurePropagationFixed.cfg models/dataflow/ParslDependencyFailurePropagation.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_dependency_runtime.py -v
```

`ParslJoinFull.tla` is the integrated bounded join model. It combines single-Future joins,
ordered list joins with duplicate positions, empty-list joins, invalid return handling, logical
inner Futures with physical retries, cancellation, failure aggregation, terminal result ordering,
and an explicit per-attempt `absent -> serialized -> running` transport stage. `MAX_RETRIES = 1`
keeps the state space small while preserving the important attempt correlation and join-handle
invariants. The full configuration checks 7,148 generated / 1,958 distinct states at depth 19
with no invariant violation. The six-case runtime bridge in
`ParslJoinFullCurrent.cfg` intentionally accepts a result from a failed attempt after a retry has
started; TLC finds `AttemptLogicalSafety` after 3,343 generated / 1,297 distinct states. The fixed
configuration rejects that old result as stale, persists the terminal outer status through the
monitoring event boundary, and checks 29,933 generated / 7,000 distinct states at depth 23.
`tests/test_join_runtime.py` exercises real decorated `join_app` behavior for single, list,
duplicate, empty, failure, and nested joins.

`ParslJoinCallableTransport.tla` adds the serialized callable boundary to that join semantics.
Each inner logical Future has per-attempt captured content, task/result wire state, and stale
late-result handling. The inner-Future set, input positions, and retry budget are parameterized;
the full configuration constructs the ordered `<<I1, I2, I1>>` result and TLC checks 16,113
generated / 3,559 distinct states at depth 20.
The concrete bridge in `tests/test_join_callable_transport_runtime.py` runs two real serialized
inner Python apps and verifies the duplicate Future position in the outer result.

`ParslJoinCallableTransportSmoke.cfg` uses one inner Future, two duplicate input positions, and no
retry for a fast regression of serialized join result ordering and stale-result safety. TLC checks
26 generated / 13 distinct states at depth 6.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslJoinCallableTransport.cfg models/dataflow/ParslJoinCallableTransport.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_join_callable_transport_runtime.py -v
```

`ParslDynamicTaskCreation.tla` models the basic parent-to-child creation boundary. The newer
`ParslDynamicTaskFanout.tla` keeps the logical children separate: completion of the parent creates
`C1` and `C2`, `C1` depends on the parent, and `C2` depends on both the parent and the successful
`C1` Future. Each child has an explicit bounded physical-attempt counter, retry transition, and
terminal Future. This captures a small dynamic DAG without conflating child creation with child
execution.

`ParslDynamicTaskChain.tla` deepens that abstraction by allowing a created child to create a
grandchild: the parent creates `C1`/`C2`, then successful `C1` creates `G`, whose dependencies are
the parent and `C1`. Creation, dependency release, logical Future resolution, and per-node retry
counters remain separate. TLC checks 100,001 simulated states with the same dependency, terminal,
and retry invariants.

```bash
java -cp tla2tools.jar tlc2.TLC -simulate num=1000 \
  -config models/dataflow/ParslDynamicTaskFanout.cfg \
  models/dataflow/ParslDynamicTaskFanout.tla
```

`ParslJoinCancellation.tla` isolates cancelled inner Futures. `Future.exception()` raises
`CancelledError` in the current callback path, so a decorated outer `join_app` can remain in
`joining`; the fixed branch converts cancellation into a terminal join failure. The direct and
end-to-end runtime probes cover both the callback method and a real decorated join.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslJoinCancellationCurrent.cfg models/dataflow/ParslJoinCancellation.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslJoinCancellationFixed.cfg models/dataflow/ParslJoinCancellation.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_join_cancellation_end_to_end_runtime.py -v
```

The list-valued cancellation model is also corroborated by
`tests/test_join_list_cancellation_end_to_end_runtime.py`: one successful member and one cancelled
member leave the decorated outer join unresolved in the current path.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslJoinFull.cfg models/dataflow/ParslJoinFull.tla
PYTHONPATH=/tmp/parsl-source:/home/cc/tla-parsl /tmp/parsl-venv/bin/python -m unittest tests/test_join_runtime.py -v
```

`ParslMemoExceptionCheckpoint.tla` models failure persistence across a memoizer restart. The
current `BasicMemoizer` updates its in-memory cache with a failed `AppFuture`, but the checkpoint
writer skips exception commands, leaving an empty `tasks.pkl`. TLC finds the four-state current
counterexample (`RunAndFail -> Checkpoint -> Restart`); the fixed branch persists the failure.
The real probe is [`tests/test_memo_exception_checkpoint_runtime.py`](../tests/test_memo_exception_checkpoint_runtime.py).
This records a semantic gap for review, not a claim that failure persistence is necessarily the
intended Parsl policy.

`ParslMemoCheckpointOrder.tla` models duplicate keys across checkpoint runs. `get_all_checkpoints`
in [`parsl/utils.py`](https://github.com/Parsl/parsl/blob/master/parsl/utils.py) sorts UUID-named
run directories lexically, while `_load_checkpoints` in
[`parsl/dataflow/memoization.py`](https://github.com/Parsl/parsl/blob/master/parsl/dataflow/memoization.py)
overwrites a key with every later file it reads. UUID order is not chronology, so an old value can
overwrite a newer one. The current TLC configuration finds the three-state counterexample; the
fixed configuration reads old then new and passes.
[`tests/test_memo_checkpoint_order_runtime.py`](../tests/test_memo_checkpoint_order_runtime.py)
creates two UUID-like directories and demonstrates the actual stale restoration.

`ParslLastCheckpointUUID.tla` models the run-directory filter in `get_last_checkpoint`. Current
DFK instances use UUID run IDs, but the helper keeps only `isdigit()` directory names, so a valid
UUID checkpoint is invisible. TLC finds the two-state current counterexample; the fixed branch
accepts the UUID directory. [`tests/test_last_checkpoint_uuid_runtime.py`](../tests/test_last_checkpoint_uuid_runtime.py)
confirms the current helper returns `[]` for a UUID directory while retaining the legacy numeric
behavior.

`ParslMemoFunctionIdentity.tla` is the source-version refinement of the closure memoization
boundary. `id_for_memo_function` currently hashes only `__name__` and `__module__`, so replacing a
function body behind the same public entry point keeps the old memo key even when the serialized
callable changes. The current TLC configuration violates `MemoKeySafety`; the fixed configuration
includes a symbolic source/version identity. The runtime probe
[`tests/test_memo_function_identity_runtime.py`](../tests/test_memo_function_identity_runtime.py)
reproduces the collision with two functions that share name/module metadata. This is recorded as
the function-body refinement of BUG-024 rather than a separate duplicate finding.

`ParslMemoIgnoreKey.tla` models validation of `ignore_for_cache` before memo-key construction.
The current `BasicMemoizer.make_hash` path deletes unknown names directly and exposes a raw
`KeyError`; the fixed branch rejects an unknown name before mutating the filtered keyword map.
The runtime probe is [`tests/test_memo_ignore_key_runtime.py`](../tests/test_memo_ignore_key_runtime.py).

`ParslMemoIgnoreOutputs.tla` covers the special `outputs` key. The current hash path can delete
that key once through `ignore_for_cache` and a second time while constructing the output reference,
whereas the fixed branch makes the operation idempotent. The runtime probe is
[`tests/test_memo_ignore_outputs_runtime.py`](../tests/test_memo_ignore_outputs_runtime.py).

```bash
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslMemoIgnoreKeyCurrent.cfg models/dataflow/ParslMemoIgnoreKey.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslMemoIgnoreKeyFixed.cfg models/dataflow/ParslMemoIgnoreKey.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_memo_ignore_key_runtime.py -v
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslMemoIgnoreOutputsCurrent.cfg models/dataflow/ParslMemoIgnoreOutputs.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslMemoIgnoreOutputsFixed.cfg models/dataflow/ParslMemoIgnoreOutputs.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_memo_ignore_outputs_runtime.py -v
```

```bash
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslMemoFunctionIdentityCurrent.cfg models/dataflow/ParslMemoFunctionIdentity.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslMemoFunctionIdentityFixed.cfg models/dataflow/ParslMemoFunctionIdentity.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_memo_function_identity_runtime.py -v
```

`ParslDependencyTraversal.tla` has explicit dictionary-value and dictionary-key configurations.
The deep resolver configurations pass with 10 distinct states each; the shallow dictionary
configuration exposes `NoNestedFutureLeak` because the nested Future reaches the worker.
The runtime dependency probe now checks both dictionary positions with the real resolver.
It also checks recursive tuple and set traversal; each deep-container configuration passes the
same dependency and no-leak invariants.

`ParslJoinComplete.tla` combines the main `join_app` cases in one bounded model: a single
Future, duplicate-preserving Future lists, empty lists, invalid returns, `None`-valued inner
results, and inner cancellation/failure. The current configuration exposes a
`JoinResultSafety` counterexample by collapsing duplicate list positions; the fixed configuration
preserves the sequence and checks 5,694 states with all six invariants passing.

`ParslJoinEndToEnd.tla` is the cross-layer join model. It keeps logical inner Futures separate
from physical attempts, allows one retry, models cancellation/final failure, and reconstructs
the duplicate-preserving outer list. The TLC configuration checks retry bounds, physical/logical
consistency, wait-for-all completion, terminal failure, and result shape. The concrete retry and
duplicate-list probes provide the corresponding Parsl runtime evidence. Additional invariants tie
every terminal logical state to its terminal physical attempt and prevent callbacks from
observing a non-terminal inner Future.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslJoinEndToEnd.cfg models/dataflow/ParslJoinEndToEnd.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_join_retry_runtime.py tests/test_join_retry_duplicates_runtime.py tests/test_join_single_cancellation_runtime.py -v
```

`ParslJoinRetry.tla` refines this with physical attempts for each inner Future. A failed
non-final attempt leaves the logical Future unresolved, so `join_app` waits for retry rather than
failing early. The model checks 258 distinct states with retry isolation and ordered aggregation;
the concrete probe is `tests/test_join_retry_runtime.py`.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslJoinRetry.cfg models/dataflow/ParslJoinRetry.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_join_retry_runtime.py -v
```

`ParslJoinRetryDuplicates.tla` combines physical inner retries with duplicate-preserving input
ordering. The current branch collapses `<<I1, I2, I1>>` to two result positions; TLC finds
`ResultOrderSafety` at depth 9 (72 distinct states). The fixed branch preserves all three
positions and checks 131 distinct states. The concrete probe is
`tests/test_join_retry_duplicates_runtime.py`.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslJoinRetryDuplicatesCurrent.cfg models/dataflow/ParslJoinRetryDuplicates.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslJoinRetryDuplicatesFixed.cfg models/dataflow/ParslJoinRetryDuplicates.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_join_retry_duplicates_runtime.py -v
```

`ParslJoinRetryCancellation.tla` combines retry-wait with list-join cancellation. The current
callback lets `CancelledError` escape after an inner retry is cancelled; TLC finds
`NoUnexpectedCallback` after 30 states. The fixed branch records cancellation as terminal inner
failure and checks 484 distinct states. The concrete cancellation callback behavior is covered by
`tests/test_join_list_cancellation_runtime.py` and `tests/test_join_single_cancellation_runtime.py`.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslJoinRetryCancellationCurrent.cfg models/dataflow/ParslJoinRetryCancellation.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslJoinRetryCancellationFixed.cfg models/dataflow/ParslJoinRetryCancellation.tla
```

`ParslTaskStatusFutureOrdering.tla` keeps logical task status separate from the public Future.
Parsl publishes `exec_done` before `AppFuture.set_result`, allowing monitoring to observe a
terminal task during the small callback-delivery window. The strict Current configuration
exposes that ordering; Fixed and Valid allow it while preserving the rule that a completed Future
always has a terminal task.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslTaskStatusFutureOrderingCurrent.cfg models/dataflow/ParslTaskStatusFutureOrdering.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslTaskStatusFutureOrderingFixed.cfg models/dataflow/ParslTaskStatusFutureOrdering.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslTaskStatusFutureOrderingValid.cfg models/dataflow/ParslTaskStatusFutureOrdering.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_task_status_future_ordering_runtime.py -v
```

`ParslJoinReturnShape.tla` makes the admission boundary explicit: a single Future, a Future-only
list, and an empty list enter `joining`; tuples, scalar values, and mixed lists fail before any
join callback is registered. The runtime probe exercises the real `join_app` decorator with a
tuple return.

`ParslNestedJoin.tla` models composition of two join callbacks. The outer join cannot complete
until the inner join is terminal; successful inner list order is preserved, and a leaf failure is
wrapped and propagated through both join layers. `tests/test_nested_join_runtime.py` exercises
both paths with the real decorators and ThreadPool executor.

`ParslJoinImmediateCallback.tla` models the already-completed inner Future race. The DFK must
enter `joining` and install `join_lock` before calling `add_done_callback`, because Python may
invoke that callback synchronously during registration. TLC checks the two callback interleavings
and the runtime `test_already_completed_inner_future_callback` exercises the real decorator.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslJoinImmediateCallback.cfg models/dataflow/ParslJoinImmediateCallback.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_join_runtime.py -v
```

`ParslDataFutureFalseyException.tla` covers the DataFuture parent callback boundary. The current
truthiness check misclassifies an exception whose `__bool__` returns false as a successful file
publication; the fixed branch checks exception presence explicitly. This is BUG-092 and is
exercised by `tests/test_datafuture_falsey_exception_runtime.py`.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslDataFutureFalseyExceptionCurrent.cfg models/dataflow/ParslDataFutureFalseyException.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslDataFutureFalseyExceptionFixed.cfg models/dataflow/ParslDataFutureFalseyException.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_datafuture_falsey_exception_runtime.py -v
```

```bash
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslNestedJoin.cfg models/dataflow/ParslNestedJoin.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_nested_join_runtime.py -v
```

```bash
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslJoinReturnShapeFuture.cfg models/dataflow/ParslJoinReturnShape.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslJoinReturnShapeList.cfg models/dataflow/ParslJoinReturnShape.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslJoinReturnShapeEmpty.cfg models/dataflow/ParslJoinReturnShape.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslJoinReturnShapeTuple.cfg models/dataflow/ParslJoinReturnShape.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslJoinReturnShapeMixed.cfg models/dataflow/ParslJoinReturnShape.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_join_return_shape_runtime.py -v
```

`ParslJoinInternalExecutor.tla` models the executor admission boundary before the join callback
protocol starts. DFK initialization creates `_parsl_internal`, and `join_app` must target that
executor explicitly. The current configuration represents a regression to the ordinary `all`
executor set and violates `InternalExecutorSafety`; the fixed configuration checks the internal
target. The runtime join probe asserts the real decorated function carries the internal executor
label.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslJoinInternalExecutorCurrent.cfg models/dataflow/ParslJoinInternalExecutor.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslJoinInternalExecutorFixed.cfg models/dataflow/ParslJoinInternalExecutor.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_join_runtime.py -v
```

The same join runtime probe also exercises `join_app(cache=True)`: both a single-Future result and
an ordered Future-list result run their outer join body once, are stored by the memoizer, and return
the same result on a second identical call without re-running the body. This supplies concrete
evidence for the memo-hit and ordered-list branches of `ParslJoinMemoData.tla`.

`ParslJoinSingleCancellation.tla` isolates cancellation of a single inner Future. The current
callback lets `Future.exception()` raise `CancelledError`, leaving the outer join in `joining`;
the fixed branch converts it into terminal failure. Its runtime probe calls the real callback.

`ParslJoinFailureAggregation.tla` refines the failure side of list-valued joins. Once every
inner Future is terminal, each failed Future contributes one exception entry in the original
join-list order; successful inner results are omitted. The runtime probe uses two real failed
Futures and checks the resulting `JoinError.dependent_exceptions_tids` sequence.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslJoinFailureAggregation.cfg models/dataflow/ParslJoinFailureAggregation.tla
```

`ParslJoinDuplicateFailureAggregation.tla` extends that rule to duplicate list positions. If the
same failed Future occurs twice in the input list, the current set-oriented abstraction loses one
`dependent_exceptions_tids` entry; the fixed branch scans list positions and preserves both. The
runtime probe calls the concrete callback with the same failed Future in both positions.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslJoinDuplicateFailureAggregationCurrent.cfg models/dataflow/ParslJoinDuplicateFailureAggregation.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslJoinDuplicateFailureAggregationFixed.cfg models/dataflow/ParslJoinDuplicateFailureAggregation.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_join_duplicate_failure_aggregation_runtime.py -v
```

`ParslJoinListMutation.tla` covers the object-identity boundary at join registration. The current
DFK stores the caller-owned Future list directly, so clearing or changing that list before the
join callback runs changes the outer result; the fixed branch snapshots the membership. TLC finds
the current `JoinSnapshotSafety` counterexample (4 generated/3 distinct states), checks 6
generated/3 distinct fixed states, and the runtime probe demonstrates the current empty result.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslJoinListMutationCurrent.cfg models/dataflow/ParslJoinListMutation.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslJoinListMutationFixed.cfg models/dataflow/ParslJoinListMutation.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslJoinListMutationStable.cfg models/dataflow/ParslJoinListMutation.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_join_list_mutation_runtime.py -v
```

`ParslJoinReturnEquality.tla` covers a return-validation hazard before the normal join callback.
The current implementation compares an arbitrary join-body result with `[]` before checking its
type; a user-defined `__eq__` can raise and strand the outer Future. The fixed branch performs
type validation first and reaches the ordinary terminal `TypeError` path. The runtime probe uses a
real `join_app` whose return object raises from `__eq__` and observes the current pending Future.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslJoinReturnEqualityCurrent.cfg models/dataflow/ParslJoinReturnEquality.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslJoinReturnEqualityFixed.cfg models/dataflow/ParslJoinReturnEquality.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_join_return_equality_runtime.py -v
```

`ParslJoinErrorRootCause.tla` captures `PropagatedException` metadata used by `JoinError`: the
first dependent exception is followed recursively to a non-propagated root, and sibling failures
are marked with `(+ others)` in the representative path. The runtime probe checks the actual
exception `__cause__` and string representation.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslJoinErrorRootCause.cfg models/dataflow/ParslJoinErrorRootCause.tla
```

`ParslRetryHandlerNegativeCost.tla` audits the retry-budget boundary in
`DataFlowKernel.handle_exec_update`. The current implementation adds the value returned by a
user `retry_handler` directly to `fail_cost`; a negative value makes every failure remain within
the retry budget and can cause unbounded physical attempts. The fixed branch rejects a negative
cost as a terminal handler error. The runtime probe uses a zero retry budget and stops the real
workflow after several otherwise-unbounded attempts. This is recorded as BUG-150.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslRetryHandlerNegativeCostCurrent.cfg models/dataflow/ParslRetryHandlerNegativeCost.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslRetryHandlerNegativeCostFixed.cfg models/dataflow/ParslRetryHandlerNegativeCost.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_retry_handler_negative_cost_runtime.py -v
```

`ParslRetryHandlerNonNumericCost.tla` covers the adjacent type boundary. A callable retry handler
that returns a string or other non-numeric value raises while updating `fail_cost`; the current
callback path can leave the outer AppFuture pending, while the fixed path reports terminal
handler failure. The runtime probe reproduces the pending Future with a one-second timeout. This
is recorded as BUG-151.

`ParslAppFutureOutputStreams.tla` records the current `AppFuture.stdout`/`stderr` property
contract. A separate stage-out `DataFuture` overrides the original task-record value; otherwise
`None`, strings, and tuples are exposed unchanged. The tuple case is deliberately modeled as an
opaque value because the source currently documents tuple stage-out handling as future work.
`tests/test_app_future_output_streams_runtime.py` checks these paths against the real `AppFuture`.

`ParslJoinBodyRetry.tla` separates retries of the join body's own physical execution from the
later inner-Future join. The outer task installs a join handle only after a body attempt succeeds;
`tests/test_join_body_retry_runtime.py` verifies this ordering with a real decorated `join_app`.

`ParslFutureWaitTimeout.tla` separates a caller-side `Future.result(timeout=...)` expiry from a
Parsl task timeout. The caller may stop waiting while the Future remains pending and can later
complete normally. `tests/test_future_wait_timeout_runtime.py` verifies this behavior with a real
Python Future.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslRetryHandlerNonNumericCostCurrent.cfg models/dataflow/ParslRetryHandlerNonNumericCost.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslRetryHandlerNonNumericCostFixed.cfg models/dataflow/ParslRetryHandlerNonNumericCost.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_retry_handler_non_numeric_cost_runtime.py -v
```
