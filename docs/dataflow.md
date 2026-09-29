# Dataflow, Future, Join, retry, and memoization models

These models cover DataFuture propagation and cancellation, dependency traversal, Future
projection and timeout, Join semantics, callback races, nested joins, retry budgets, memoization,
resource admission, and result races.

Files live in [`models/dataflow/`](../models/dataflow/).

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

```bash
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslJoinReturnShapeFuture.cfg models/dataflow/ParslJoinReturnShape.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslJoinReturnShapeList.cfg models/dataflow/ParslJoinReturnShape.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslJoinReturnShapeEmpty.cfg models/dataflow/ParslJoinReturnShape.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslJoinReturnShapeTuple.cfg models/dataflow/ParslJoinReturnShape.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslJoinReturnShapeMixed.cfg models/dataflow/ParslJoinReturnShape.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_join_return_shape_runtime.py -v
```

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

`ParslJoinErrorRootCause.tla` captures `PropagatedException` metadata used by `JoinError`: the
first dependent exception is followed recursively to a non-propagated root, and sibling failures
are marked with `(+ others)` in the representative path. The runtime probe checks the actual
exception `__cause__` and string representation.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslJoinErrorRootCause.cfg models/dataflow/ParslJoinErrorRootCause.tla
```
