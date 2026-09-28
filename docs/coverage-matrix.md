# Abstraction coverage matrix

This repository intentionally uses bounded abstractions. The table below records what is
currently modeled, which runtime probes corroborate it, and where the abstraction is still
coarse. A passing TLC run is evidence for the listed finite model, not a proof of all Parsl
implementations or every detail in the paper.

| Area | TLA+ coverage | Runtime evidence | Remaining coarse boundary |
| --- | --- | --- | --- |
| Core DFK lifecycle | ParslAbstract, ParslEndToEnd, ParslDataFlowCleanup, ParslDataFlowWaitSnapshot | DataFlow cleanup, wait-snapshot, and integration probes | Component internals remain bounded and symbolic |
| ZMQ and serialization | ParslZMQ, ParslSerializationWire, ParslZMQSerializationEndToEnd, ParslSerializationFallback, dynamic plugin cache, ResultsIncoming, TasksOutgoing, HTEX manager identity boundary | test_zmq_serialization_runtime.py, ResultsIncoming/TasksOutgoing, serializer fallback/cache, manager-message, and serializer/frame-count probes | Bounded queues and symbolic bytes; no full distributed timing model |
| Python functions and object contents | ParslPython, ParslSerializationSnapshot, ParslCallableClosureMemo, ParslCallableMutationCache | test_serialization_runtime.py, callable mutation-cache, test_memo_closure_runtime.py, tools/cloudpickle_fixture.py | Object graphs are finite symbolic nodes rather than arbitrary Python heaps |
| Files and transfer | ParslFileBytes, ParslDataFutureTransfer, ParslDataFutureCancellationPropagation, ParslFilePathResolution, ParslDataManagerStageInOrdering, JobStatus output summaries, and staging-provider models | file, DataFuture/cancellation, File path, output-summary, DataManager ordering, FTP/HTTP/Rsync/Zip/Globus probes | Chunk counts and content versions are bounded |
| Time, heartbeat, timeout | ParslTimedHeartbeat, ParslHeartbeatClockJump, ParslHeartbeatClockRollback, ParslHeartbeatLateAck, ParslPeriodicTimer, ParslWorkerContactTimeout | heartbeat, deadline, command-timeout, periodic-timer, and worker-contact probes | Logical time replaces OS scheduling and network latency |
| Monitoring database | ParslMonitoringDelivery, ParslMonitoringDB, ParslMonitoringTaskRetry, ParslMonitoringLastMessageRace, ParslMonitoringShutdownDrain, ParslMonitoringShutdownRace, HTEX monitoring-message boundary | monitoring DB retry, batching, atomicity, close, deferred-ordering, shutdown-drain/race, and HTEX payload probes | Database schema and transaction batches are reduced to finite records |
| Executors/providers | lifecycle, HTEX, manager selection, manager drain, ResultsIncoming, TasksOutgoing, WorkQueue/TaskVine shutdown, Flux submission failure, RadicalPilot failure payload, unknown-manager isolation, ClusterProvider script generation, Thread, WorkQueue, Flux, TaskVine, LocalProvider, `ParslBlockProviderBadState`, scheduler-specific models, and the strategy policy | 283 local/fake-provider runtime tests, including strategy scaling probes | Not every backend implementation is modeled at identical depth |
| join_app | ParslJoinComplete, failure aggregation, root-cause metadata, callback/cancellation/mutation/nested/memo-data models, and single-Future cancellation | join, multi-failure, root-cause, callback, cancellation, mutation, None, and single-cancellation probes | Python exception identity and arbitrary user object graphs remain abstract |

The next refinements should select one row, read the relevant source path, and add a focused
model plus a runtime probe before expanding the state space.
