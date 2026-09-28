# Abstraction coverage matrix

This repository intentionally uses bounded abstractions. The table below records what is
currently modeled, which runtime probes corroborate it, and where the abstraction is still
coarse. A passing TLC run is evidence for the listed finite model, not a proof of all Parsl
implementations or every detail in the paper.

| Area | TLA+ coverage | Runtime evidence | Remaining coarse boundary |
| --- | --- | --- | --- |
| ZMQ and serialization | ParslZMQ, ParslSerializationWire, ParslZMQSerializationEndToEnd | test_zmq_serialization_runtime.py and serializer/frame-count probes | Bounded queues and symbolic bytes; no full distributed timing model |
| Python functions and object contents | ParslPython, ParslSerializationSnapshot, ParslCallableClosureMemo | test_serialization_runtime.py, test_memo_closure_runtime.py, tools/cloudpickle_fixture.py | Object graphs are finite symbolic nodes rather than arbitrary Python heaps |
| Files and transfer | ParslFileBytes, ParslDataFutureTransfer, ParslFilePathResolution, JobStatus output summaries, and staging-provider models | file, DataFuture, File path, output-summary, FTP/HTTP/Rsync/Zip/Globus probes | Chunk counts and content versions are bounded |
| Time, heartbeat, timeout | ParslTimedHeartbeat, ParslHeartbeatClockJump, ParslHeartbeatClockRollback, ParslHeartbeatLateAck | heartbeat, deadline, and command-timeout probes | Logical time replaces OS scheduling and network latency |
| Monitoring database | ParslMonitoringDelivery, ParslMonitoringDB, ParslMonitoringTaskRetry, HTEX monitoring-message boundary | monitoring DB retry, batching, atomicity, close, and HTEX payload probes | Database schema and transaction batches are reduced to finite records |
| Executors/providers | lifecycle, HTEX, manager selection, manager drain, Thread, WorkQueue, Flux, TaskVine, LocalProvider, `ParslBlockProviderBadState`, and scheduler-specific models under models/executors/ and models/providers/ | 250 local/fake-provider runtime tests | Not every backend implementation is modeled at identical depth |
| join_app | ParslJoinComplete, failure aggregation, callback/cancellation/mutation/nested/memo-data models | join, multi-failure, callback, cancellation, mutation, and None probes | Python exception identity and arbitrary user object graphs remain abstract |

The next refinements should select one row, read the relevant source path, and add a focused
model plus a runtime probe before expanding the state space.
