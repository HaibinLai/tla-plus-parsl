# Core workflow models

The shared `ParslAbstract` model covers logical task/Future state, physical attempts, dependency
blocking, workers, executors, providers, retries, memoization, data readiness, and stale results.

Files live in [`models/core/`](../models/core/). Start with `ParslAbstract.tla` and its scenario
configurations such as `ParslNoFailures.cfg`, `ParslTime.cfg`, and `ParslProviderFailure.cfg`.

`ParslDataReadyExecution.tla` is the cross-layer data-readiness model: stage-in captures a source
version, transfers bounded chunks, publishes a ready DataFuture, and only then admits a dependent
task. The current branch can publish a stale captured version if the source changes during
transfer; the fixed branch marks the transfer stale and retries. The real byte-level dependency
bridge is `tests/test_datafuture_runtime.py`.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/core/ParslDataReadyExecutionCurrent.cfg models/core/ParslDataReadyExecution.tla
java -cp tla2tools.jar tlc2.TLC -config models/core/ParslDataReadyExecutionFixed.cfg models/core/ParslDataReadyExecution.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_datafuture_runtime.py -v
```

`ParslDataTransferDependencyFailure.tla` closes the stage-out/dataflow loop.  A producer finishes,
the DataManager transfers a bounded output in chunks, and a DataFuture becomes ready only after
publication.  If the stage-out fails, the consumer remains blocked and is completed as a
dependency failure; it never executes against a partial file.  The Current configuration permits
consumer admission on a failed DataFuture and TLC finds the counterexample.  The Fixed
configuration checks no-partial-execution, failure propagation, publication atomicity, and terminal
result consistency.  The runtime bridge is `tests/test_datafuture_runtime.py`, including the
failed-output case where the consumer function is never called.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/core/ParslDataTransferDependencyFailureCurrent.cfg models/core/ParslDataTransferDependencyFailure.tla
java -cp tla2tools.jar tlc2.TLC -config models/core/ParslDataTransferDependencyFailureFixed.cfg models/core/ParslDataTransferDependencyFailure.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_datafuture_runtime.py -v
```

For a fast executable smoke check, `ParslAbstractSmoke.cfg` reduces the abstraction to one local
task, one worker, no dependencies, no retries, and no provider blocks. It is useful for validating
changes to the shared model before launching the much larger multi-task configuration.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/core/ParslAbstractSmoke.cfg models/core/ParslAbstract.tla
```

`ParslAbstractJoinSmoke.cfg` is the corresponding join-focused smoke check. It keeps two inner
tasks and one outer join task while removing provider, file, monitoring, retry, and failure
branching. This gives a small regression target for the join state transitions before running the
full `ParslJoinSafety.cfg` composition.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/core/ParslAbstractJoinSmoke.cfg models/core/ParslAbstract.tla
```

`ParslEndToEnd.tla` is the deliberately small integration model. It connects dependency release,
task serialization, wire delivery, worker execution, result delivery, retry/timeout, and late
results. `ParslEndToEnd.cfg` intentionally permits an old attempt to resolve the Future and TLC
finds a `StaleResultSafety` counterexample. `ParslEndToEndFixed.cfg` rejects that result as stale;
TLC checks 198 states with all invariants passing. The model also checks
`CurrentAttemptResultSafety`: a result arriving after the current physical attempt has timed out
or failed must not resolve the logical Future merely because its retry number still matches
`currentAttempt`. The current configuration reaches this counterexample in 23 states; the fixed
configuration classifies the result as stale. This complements the retry/timeout probes in
`tests/test_retry_timeout_runtime.py` while keeping logical tasks separate from physical attempts.

`ParslTaskStagingMonitoring.tla` combines producer task completion, chunked stage-out/DataFuture
publication, dependent-consumer admission, and asynchronous monitoring persistence. The current
configuration permits a success row (and a ready DataFuture) before all chunks are received;
the fixed configuration gates both observations on complete stage-out and checks 21 states.

`ParslPipeline.tla` composes the same boundaries with payload serialization, physical worker
attempts, retry/result correlation, output stage-out, DataFuture readiness, and monitoring
persistence. Its current configuration reaches the early-monitoring counterexample in 435
generated / 221 distinct states; the fixed configuration passes in 228 generated / 85 distinct
states at depth 22. `ParslPipelineSmoke.cfg` is the one-chunk/no-retry fixed check (32 generated /
16 distinct, depth 13). The action mapping follows `parsl/dataflow/dflow.py`,
`parsl/data_provider/data_manager.py`, `parsl/serialize/facade.py`, and the monitoring database
writer.

`ParslPipelineTimed.tla` is a deliberately smaller cross-layer composition for the timing and
monitoring boundary. It keeps a two-node logical DAG (`A -> B`), gives each physical attempt its
own deadline, models manager heartbeat expiry, retry admission, and late completion separately
from the logical task state, and sends terminal events through an explicit
`EmitStatus -> PersistStatus` queue. `ParslPipelineTimedCurrent.cfg` accepts a completion from an
attempt whose task was already marked `manager_lost`; TLC finds the `TerminalCauseSafety`
violation after 1,698 generated / 827 distinct states. `ParslPipelineTimedFixed.cfg` records that
completion as stale and passes dependency, retry, result, terminal-cause, stale-result, and
database-cause invariants with 225,836 generated / 51,703 distinct states at depth 24. This model
is intentionally complementary to the larger `ParslPipeline.tla`: it makes the logical-task
versus physical-attempt, clock, and monitoring boundaries easy to inspect before adding more
executor/provider detail.

The combined join configuration `models/core/ParslJoinSafety.cfg` has also been checked against
the shared `ParslAbstract` module. It explores 427,320 generated states (66,459 distinct states,
depth 61) with dependency, Future, retry, join-result, join-handle, and join-failure invariants
all passing. This is a bounded composition check; the focused `models/dataflow/` join models
remain preferable for larger duplicate, cancellation, memoization, and callback-race scenarios.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/core/ParslTaskStagingMonitoringCurrent.cfg models/core/ParslTaskStagingMonitoring.tla
java -cp tla2tools.jar tlc2.TLC -config models/core/ParslTaskStagingMonitoringFixed.cfg models/core/ParslTaskStagingMonitoring.tla
```

`FinishProducer` represents the DFK logical result, `PublishStageOut` the DataManager/DataFuture
readiness boundary, `StartConsumer` dependency admission, and the monitoring actions event and
database delivery. The focused chunk protocol remains in
`models/staging/ParslDataFutureTransfer.tla`.

`ParslProviderFailureRetry.tla` connects provider block failure to executor attempt loss and
retry. It permits an old worker result to arrive after a retry begins. The current configuration
violates `FutureSafety` at depth 6; the fixed configuration classifies that result as stale and
checks 79 distinct states. This corresponds to provider status/failure handling, executor
physical-attempt bookkeeping, and the retry path. The Python retry baseline is exercised by
`tests/test_retry_timeout_runtime.py` and `tests/test_retry_handler_runtime.py`.

`ParslResultDecodeRetry.tla` adds the ZMQ/result boundary: a completed worker result can be
corrupt at deserialization, causing the physical attempt to be retried while the old frame is
still deliverable. Current TLC finds the stale-resolution violation at depth 5; Fixed rejects
the old frame and checks 18 distinct states. The concrete corrupt-result behavior is covered by
`tests/test_htex_result_decode_failure_runtime.py` and
`tests/test_htex_result_queue_runtime.py`.

The detailed action-to-Parsl mapping and TLC results are in [the overview](overview.md).

## Foundational smoke suite

Before running the larger model inventory, `scripts/tlc_foundational_smoke.sh` checks the
small first-stage abstractions that establish the repository's main boundaries: a dependency
and retry path, callable/object snapshotting, chunked file bytes, heartbeat time, monitoring
database persistence, `join_app`, and an end-to-end ZMQ/serialization route. The suite uses
TLC simulation with bounded state and exits on the first failing model. Java and TLC can be
provided explicitly when they are not on `PATH`:

```bash
JAVA_BIN=/path/to/java TLA_JAR=/path/to/tla2tools.jar \
  TLC_SIMULATE=1000 scripts/tlc_foundational_smoke.sh
```

This is a regression entry point, not a replacement for the exhaustive TLC configurations or
the concrete Python runtime probes documented by each module.

The final three cases also pin down the first executor-specific refinement after the simple
abstractions: HTEX submit queue rollback, result-deserialization failure cleanup, and rejection
of a result frame that carries both a result and an exception. Their current configurations are
kept as counterexamples in the executor/serialization documentation; the smoke suite runs the
fixed configurations so the foundational path remains green.

The provider cases then sample concrete admission and response boundaries across Kubernetes,
Torque, LocalProvider, AWS, and Google Cloud. They are deliberately small schema/state checks;
the provider-specific documents and runtime probes remain the authoritative deeper models.

The last case, `ParslProviderExecutorTimedMonitoringFixed`, is the first combined dynamic path in
this smoke suite: provisioning, manager heartbeat expiry, task timeout/retry, stale old-attempt
results, monitoring persistence, and scale-in/scale-out admission are checked together. Its
exhaustive configuration remains documented in `docs/executor-provider-model.md` because the
full state space is intentionally larger than the smoke bound.

`ParslJoinFull.cfg` is the corresponding fixed join composition. It adds join-body execution,
serialized callable admission, duplicate-preserving input positions, inner retry attempts,
outer cancellation, stale-result rejection, failure aggregation, and terminal monitoring to the
small `ParslJoinApp` protocol. Focused models remain the place for individual callback races and
backend-specific details.

The monitoring cases cover the next database refinement: all-or-nothing batch publication,
persistent retry of transient writes, and explicit terminal handling for permanent insert/update
errors. They complement the smaller `ParslMonitoringDBSmoke` path without making the smoke suite
depend on an unbounded database or queue.

`ParslDataFlowCleanup.tla` captures the DFK shutdown sequence: mark cleanup, close memoization
and usage tracking, stop the status poller, shut down executors, close monitoring, and terminate
the task-launch pool. A repeated cleanup call is rejected without re-closing components. The
runtime probe invokes the real `DataFlowKernel.cleanup` with recording components.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/core/ParslDataFlowCleanup.cfg models/core/ParslDataFlowCleanup.tla
```

`ParslDataFlowWaitSnapshot.tla` models the documented race in
`DataFlowKernel.wait_for_current_tasks`: the method snapshots task records before waiting, so a
task inserted afterward can remain pending when the call returns and cleanup proceeds. The current
configuration exposes both `NoPendingTaskAtReturn` and `NoPendingTaskAtCleanup`; the fixed
configuration adds a late-task drain/check. The runtime probe uses a dictionary that inserts a task
immediately after the real snapshot operation.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/core/ParslDataFlowWaitSnapshotCurrent.cfg models/core/ParslDataFlowWaitSnapshot.tla
java -cp tla2tools.jar tlc2.TLC -config models/core/ParslDataFlowWaitSnapshotFixed.cfg models/core/ParslDataFlowWaitSnapshot.tla
```
