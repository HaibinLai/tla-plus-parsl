# Core workflow models

The shared `ParslAbstract` model covers logical task/Future state, physical attempts, dependency
blocking, workers, executors, providers, retries, memoization, data readiness, and stale results.

Files live in [`models/core/`](../models/core/). Start with `ParslAbstract.tla` and its scenario
configurations such as `ParslNoFailures.cfg`, `ParslTime.cfg`, and `ParslProviderFailure.cfg`.

`ParslEndToEnd.tla` is the deliberately small integration model. It connects dependency release,
task serialization, wire delivery, worker execution, result delivery, retry/timeout, and late
results. `ParslEndToEnd.cfg` intentionally permits an old attempt to resolve the Future and TLC
finds a `StaleResultSafety` counterexample. `ParslEndToEndFixed.cfg` rejects that result as stale;
TLC checks 207 states with all invariants passing.

`ParslTaskStagingMonitoring.tla` combines producer task completion, chunked stage-out/DataFuture
publication, dependent-consumer admission, and asynchronous monitoring persistence. The current
configuration permits a success row (and a ready DataFuture) before all chunks are received;
the fixed configuration gates both observations on complete stage-out and checks 21 states.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/core/ParslTaskStagingMonitoringCurrent.cfg models/core/ParslTaskStagingMonitoring.tla
java -cp tla2tools.jar tlc2.TLC -config models/core/ParslTaskStagingMonitoringFixed.cfg models/core/ParslTaskStagingMonitoring.tla
```

`FinishProducer` represents the DFK logical result, `PublishStageOut` the DataManager/DataFuture
readiness boundary, `StartConsumer` dependency admission, and the monitoring actions event and
database delivery. The focused chunk protocol remains in
`models/staging/ParslDataFutureTransfer.tla`.

The detailed action-to-Parsl mapping and TLC results are in [the overview](overview.md).

`ParslDataFlowCleanup.tla` captures the DFK shutdown sequence: mark cleanup, close memoization
and usage tracking, stop the status poller, shut down executors, close monitoring, and terminate
the task-launch pool. A repeated cleanup call is rejected without re-closing components. The
runtime probe invokes the real `DataFlowKernel.cleanup` with recording components.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/core/ParslDataFlowCleanup.cfg models/core/ParslDataFlowCleanup.tla
```

`ParslDataFlowWaitSnapshot.tla` models the documented race in
`DataFlowKernel.wait_for_current_tasks`: the method snapshots task records before waiting, so a
task inserted afterward can remain pending when the call returns. The current configuration
exposes `NoPendingTaskAtReturn`; the fixed configuration adds a late-task drain/check. The runtime
probe uses a dictionary that inserts a task immediately after the real snapshot operation.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/core/ParslDataFlowWaitSnapshotCurrent.cfg models/core/ParslDataFlowWaitSnapshot.tla
java -cp tla2tools.jar tlc2.TLC -config models/core/ParslDataFlowWaitSnapshotFixed.cfg models/core/ParslDataFlowWaitSnapshot.tla
```
