# A Small TLA+ Abstraction of Parsl

This repository contains an executable, finite-state abstraction of Parsl. It is not a
line-by-line translation of the Python implementation. It preserves the control-flow
boundaries that affect observable workflow behavior: DataFlowKernel task/Future state,
executor submission, worker execution, provider capacity, retries, memoization, data
readiness, and late results.

The model was based on the Parsl paper and the current source tree, especially:

- `parsl/dataflow/states.py`: task states. The usual DFK success path is
  `pending -> launched -> exec_done`; `running`/`running_ended` are primarily monitoring-side states.
- `parsl/dataflow/dflow.py`: dependency resolution, dependency failure, memoization,
  executor submission, and completion callbacks.
- `parsl/executors/high_throughput/executor.py`: HTEX task submission, provider scaling,
  and manager capacity.
- `parsl/executors/high_throughput/interchange.py`: pending queue, manager registration,
  heartbeats, dispatch, result forwarding, and manager loss.
- `parsl/executors/high_throughput/process_worker_pool.py`: worker availability and task execution.
- `parsl/providers/base.py` and `parsl/jobs/strategy.py`: provider submit/status/cancel
  interfaces and scaling policy.
- `parsl/data_provider/data_manager.py`: the data-staging abstraction boundary.

## Logical tasks and physical attempts

The most important modeling decision is to keep a logical workflow task separate from a
physical execution attempt. An attempt is identified by `(task, retryIndex)`, so `(A,0)`
and `(A,1)` are distinct executions.

Logical task/Future states:

```text
pending -> staging -> ready -> queued -> running -> succeeded
                                      \-> retry_wait -> queued
                                      \-> failed
ready --memoization hit--> memoized
```

Physical attempt states:

```text
absent -> submitted -> serialized -> sent -> received -> decoded -> dispatched -> running -> succeeded
                                             \-> result_serialized -> result_sent
                                                 -> result_received -> result_decoded -> succeeded
                                             \-> failed
                                             \-> timed_out
                                             \-> lost
failed/timed_out/lost --late result--> stale
```

Once an old attempt is replaced, a late result can only mark that physical attempt as
`stale`; it cannot overwrite the logical Future or final result. This allows TLC to explore
retry + late-result, timeout, worker-loss, and duplicate-completion scenarios.

The provider uses `none/requested/active/failed/cancelled`; workers use
`unregistered/idle/busy/failed`. Workers begin as `unregistered` and must pass through
`RegisterWorker` before becoming idle, matching the HTEX interchange manager-registration
boundary.
Executors additionally use `up/draining/down`; `ExecutorDrain` blocks new submissions while
existing attempts may continue, and `ExecutorRecover` reopens submission.
`RequestAllocation`, `AllocationSucceeds`, and `AllocationFails` abstract resource request,
resource availability, and allocation failure. Memoization completes a task without creating
an attempt or consuming a worker.
The reserved executor name `local` models a provider-free local executor: it still uses the
same serialized task/result and worker-binding protocol, but does not require a provider block.
Its workers start idle without HTEX manager registration. `ParslLocalExecutor.cfg` checks this
path separately from provider-backed executors.
Scale-in is block-granular: cancelling one of several active blocks keeps the provider active,
while cancelling the final block transitions it to `cancelled`. `ParslScaleIn.cfg` exercises this
multi-block case. Scale-out may also fail while an earlier block remains active; in that case the
failed request is rolled back to the existing active target instead of taking the whole provider
offline. `CancelRequestedAllocation` covers cancelling a pending block request before it becomes
active. The model now exposes a `MIN_BLOCKS` floor: active and pending scale-in cannot remove
capacity below that floor. `ParslMinBlocks.cfg` exercises a provider that must retain one block.

`ParslStrategy.tla` is a separate focused model of the core policy in Parsl's strategy layer:
active-task pressure is compared with slots (`blocks * SLOTS_PER_BLOCK`), scale-out is bounded by
`MAX_BLOCKS`, and idle scale-in stops at `MIN_BLOCKS` after `MAX_IDLE_TIME`. It is intentionally
kept separate from the DFK protocol state machine so strategy bugs can be isolated with a small
state space. The policy is based on `parsl/jobs/strategy.py` in the current Parsl source.

`ParslZMQ.tla` is the next focused transport model. It represents a multipart message as a
header/body encoding protocol, a bounded outbound/inbound queue pair, ROUTER/DEALER-style endpoint
identity and route checks, disconnect/drop, queue reordering, duplicate delivery, invalid payloads,
and receiver-side correlation by `(task, attempt, kind)`. It is deliberately independent of the
DFK model so transport counterexamples remain short and interpretable.

`ParslPython.tla` refines callable serialization into Python-like object categories: function
code, globals, defaults, closure cells, arguments, and nested references. Encoding traverses the
referenced graph before creating a symbolic pickle token; decoding traverses it again before a
payload is considered reconstructed. `ParslPythonFailure.cfg` marks a nested closure object as
unserializable and checks that the task fails before a token or decoded payload is exposed.

`ParslFileBytes.tla` models file contents as bounded symbolic byte chunks rather than a single
content flag. Each chunk carries a checksum through a temporary transfer buffer; corruption forces
repair/retransfer, and an input whose source version changes during stage-in becomes `stale`.
Stage-in and stage-out publish atomically only after every chunk is complete and validated.

`ParslStageOutFuture.tla` refines the DataManager/DataFlowKernel output boundary. It distinguishes
separate stage-out (the output `DataFuture` follows a returned staging Future), in-task stage-out
(the wrapper makes publication part of application completion), and the no-staging `None` path.
The separate path includes failure, retry, and the rule that dependent work cannot start until the
published output is ready. This follows
[`data_manager.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/data_provider/data_manager.py)
and the output handling in
[`dflow.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/dataflow/dflow.py).

`ParslClock.tla` separates wall-clock progression from heartbeat delivery and attempt deadlines.
It models heartbeat send/drop/delivery, manager expiry and recovery, per-attempt timeout, retry
selection after both task timeout and manager loss, and a late result that is marked stale when its
physical attempt is no longer current. A manager-lost attempt can now retry after reconnection;
its late result is explicitly allowed to arrive but cannot resolve the Future.
`ParslClockTerminal.cfg` fixes the retry budget at zero to exercise terminal timeout rejection.

`ParslHeartbeatBoundary.tla` makes the HTEX heartbeat boundary explicit: expiration occurs only
when `now - last_heartbeat > heartbeat_threshold`, a heartbeat received before the expiry check
resets the timestamp, and expiration converts all manager in-flight tasks into failure reports.
The finite model mirrors the main-loop ordering in
[`interchange.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/executors/high_throughput/interchange.py).

`ParslMonitoringDB.tla` models a versioned monitoring radio queue and asynchronous database writer.
The queue can reorder events, writes can fail and be retried, stale versions are ignored, and a
terminal database record is not overwritten by an older event. `MAX_FAILURES` and queue bounds
keep the monitoring model finite for TLC.

`ParslMonitoringDeferred.tla` adds the concrete database-manager race for worker task messages.
When a worker's first status/resource message arrives before the DFK inserts the corresponding
task/try rows, the message is deferred and replayed after the try row exists. A second first
message replaces the single deferred entry, while status rows are never written before their try
foreign key exists. This follows the deferred-message sets and replay logic in
[`monitoring/db_manager.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/monitoring/db_manager.py).

`ParslExecutorProvider.tla` is a focused model of the HTEX/BlockProviderExecutor boundary. It
separates provider block requests and failures from executor admission, manager registration,
worker readiness, queued/running tasks, drain/recovery, and block-granular scale-in. Provider
failure and scale-in explicitly clean up queued tasks for resubmission and mark running tasks
lost; an active provider block alone never implies that `submit` is accepted.

`ParslJoinApp.tla` models the bounded `join_app` result protocol. The outer app may return one
Future, a list of Futures, an empty list, or an invalid value. A join handle remains live until
all selected inner Futures are terminal; successful list results preserve input order, and any
inner failure becomes an outer join failure. Inner retries are intentionally owned by the inner
tasks, matching Parsl's callback behavior.

`ParslJoinDuplicates.tla` refines list joins beyond set-based dependency tracking. It models a
joinable list shaped like `[I1, I1, I2]`, registers callbacks by list position, preserves the
duplicate result in the aggregate, and counts a failed repeated Future once per list occurrence.
Callbacks delivered again after a position has already been observed are harmless. This follows
the list registration, all-done gate, ordered `future.result()` aggregation, and exception scan in
[`dflow.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/dataflow/dflow.py).

`ParslJoinMixedList.tla` isolates the list-shape validation boundary. A list containing only
Futures is observed and aggregated in order, an empty list completes immediately, and a mixed
list such as `[Future, 7]` fails with a TypeError-like result before any inner callback is
registered. This follows the join branch in
[`dflow.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/dataflow/dflow.py).

`ParslJoinRetry.tla` refines that protocol with separate logical inner Futures and physical inner
attempts. A retryable inner failure leaves the Future unresolved, so the outer join waits; only a
final-attempt failure is propagated as `JoinError`, while a later successful retry contributes its
final result to the ordered aggregate.

`ParslNestedJoin.tla` adds a nested join: the outer join observes a direct Future and a Future
produced by another join. The nested handle remains live until both leaf Futures are observed;
nested success/failure then becomes the only state visible to the outer join.

`ParslTaskTransport.tla` connects object-graph serialization to the task/result wire protocol.
It checks multipart encode order, envelope corruption, decode rejection, dispatch admission,
worker loss, retry correlation, result serialization failure, and stale results from an old
physical attempt. `ParslTaskTransportFailure.cfg` uses a non-serializable object graph to exercise
the pre-dispatch failure path.

The repository also contains [`tools/cloudpickle_fixture.py`](tools/cloudpickle_fixture.py) and
an observed fixture at [`fixtures/cloudpickle_fixture.json`](fixtures/cloudpickle_fixture.json).
The script serializes a closure with globals, defaults, arguments, and nested objects, checks the
round trip, and verifies that a `threading.Lock` captured by a closure is rejected. Pickle length
and SHA-256 are recorded as versioned observations, not universal constants:

```bash
python3 tools/cloudpickle_fixture.py --output fixtures/cloudpickle_fixture.json
```

The checked observation used cloudpickle 2.0.0, 776 bytes, and round-trip result `42`; a lock
closure raised `TypeError`.

`ParslProviderPolling.tla` refines the provider side of the executor model into explicit
`submit`, `status`, and `cancel` API calls. It distinguishes pending/running/unknown status,
transient API errors, submit rejection, cancel failure rollback, and desired block-target updates;
bounded poll/failure counters keep the state space finite.

`ParslExecutorKinds.tla` adds a small executor contract matrix. It distinguishes provider-free
thread execution from provider-backed HTEX/MPI/workqueue-style paths, makes manager registration
explicit where required, rejects unsupported resource specifications, and checks submit,
drain/recovery, provider failure, and executor failure behavior. The model is based on the
abstract executor lifecycle in [`base.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/executors/base.py),
the provider-free [`threads.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/executors/threads.py),
and the manager/provider boundary in
[`high_throughput/executor.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/executors/high_throughput/executor.py).
It is a contract-level comparison, not a full implementation of every executor.

`ParslMPISpec.tla` is the first MPI-specific refinement. It models the current MPI resource
specification keys (`ranks_per_node`, `num_nodes`, `num_ranks`, and `launcher_options`), the
derived-rank step, and the requirement that a provider use `SimpleLauncher`. The actual
configuration preserves the current validation shape and finds a zero-node derivation path when
`num_nodes=0` and `num_ranks` is supplied without `ranks_per_node`; the fixed configuration adds
the candidate positive-node admission guard. This follows
[`mpi_executor.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/executors/high_throughput/mpi_executor.py)
and [`mpi_prefix_composer.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/executors/high_throughput/mpi_prefix_composer.py).

`ParslExecutorShutdown.tla` makes the shutdown distinction executable. ThreadPool shutdown keeps
accepted work eligible to complete before the executor reaches `stopped`; WorkQueue shutdown has
an explicit collector-cleanup action that fails work left behind when its submit process exits;
HTEX closes the interchange first and models in-flight cleanup as a separate loss event, matching
the fact that worker termination is handled by scaling or heartbeat expiry. All three paths reject
new submissions after shutdown begins. The mapping follows the concrete shutdown methods in
[`threads.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/executors/threads.py),
[`workqueue/executor.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/executors/workqueue/executor.py),
and [`high_throughput/executor.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/executors/high_throughput/executor.py).

`ParslWorkQueueResults.tla` models the WorkQueue collector's result-file boundary. A valid
deserialized value resolves the executor Future, a corrupt result file or an app-produced
exception becomes a failed Future, and a report without a result file also fails. If the submit
process/collector exits, the final cleanup action fails every remaining outstanding task. This
follows `_collect_work_queue_results` in
[`workqueue/executor.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/executors/workqueue/executor.py).

`ParslFluxResult.tla` models the Flux executor's wrapped Future boundary. A Flux job must finish
before the callback reads the result file; zero exit status still requires a valid serialized
result, while missing/malformed files and task exceptions fail the Parsl Future. The actual
configuration also probes cancellation: the current callback returns immediately for a cancelled
underlying Flux future, which can leave the wrapper Future running. The fixed configuration
propagates cancellation to the wrapper. This follows
[`flux/executor.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/executors/flux/executor.py).

`ParslTaskVineResults.tla` models the TaskVine executor's ready-task queue, manager report, and
collector thread. It maps valid result files to success, missing/corrupt files and application
exceptions to failed Futures, and models collector finalization failing every outstanding task
when the TaskVine submit process dies. The model follows
[`taskvine/executor.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/executors/taskvine/executor.py)
and the report construction in
[`taskvine/manager.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/executors/taskvine/manager.py).

`ParslRadicalPilotResults.tla` models RadicalPilot task callbacks for Bash, Python, and MPI-like
tasks: DONE maps to an exit code, deserialized value, or raw MPI return; CANCELED cancels the
Future; FAILED sets an exception; and a master failure fails all outstanding tasks. The actual
configuration probes shutdown with a pending RP task, because the current `shutdown()` closes the
session without an explicit sweep of `future_tasks`; the fixed configuration adds that sweep.
This follows [`radical/executor.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/executors/radical/executor.py).

`ParslGlobusComputeConfig.tla` models the thin Globus Compute wrapper's temporary resource
configuration. Each submit copies a task-specific specification into the shared SDK executor,
calls the underlying submit, and restores defaults in `finally`. The unsynchronized configuration
finds cross-task specification use under interleaving submits; the serialized configuration
captures the caller-side lock required to make the wrapper safe. This follows
[`globus_compute.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/executors/globus_compute.py).

`ParslProviderKinds.tla` refines the provider side with concrete backend semantics. It models
the common `ExecutionProvider` API (`submit`, `status`, and `cancel`), Slurm-like cluster status
translation, Kubernetes pod status translation, scheduler command failure, missing-job behavior,
timeout as distinct from failure, cancellation success/failure, executor-driven `SCALED_IN`,
and CPU-per-task admission. It also covers Slurm `SUSPENDED` to `HELD` and `REQUEUED` to
`PENDING` translations while preserving terminal-state stability.
The missing-job rule intentionally preserves the current Slurm provider behavior (a job absent
from `squeue` is treated as completed) while Kubernetes reports an unknown pod as `UNKNOWN`.

`ParslAWSProviderStatus.tla` adds a cloud-provider-specific status boundary. It models EC2
`pending`/`running`/`terminated` translation and the case where a requested instance ID is absent
from the `describe_instances` response. The actual configuration preserves the current behavior
and exposes an incomplete status result; the fixed configuration supplies a terminal completion
mapping for the missing instance. This follows
[`aws.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/providers/aws/aws.py).
This is a bounded status-mapping model, not a shell or Kubernetes API emulator. It is based on
[`providers/base.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/providers/base.py),
[`providers/cluster_provider.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/providers/cluster_provider.py),
[`providers/slurm/slurm.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/providers/slurm/slurm.py),
[`providers/kubernetes/kube.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/providers/kubernetes/kube.py),
and [`jobs/states.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/jobs/states.py).

`ParslKubernetesPolling.tla` is a source-level bug probe for Kubernetes pod reads. The actual
configuration (`USE_FIXED = FALSE`) reproduces the current exception branch: a failed pod read
records an API error but leaves a running job in `RUNNING`, because the source uses an identity
comparison against a newly constructed `JobStatus` object. TLC produces a two-state counterexample.
The companion fixed configuration (`USE_FIXED = TRUE`) represents the intended value-based check
and proves that every read error exposes `UNKNOWN` while terminal states remain stable. A likely
source fix is to test `status.state == JobState.RUNNING` rather than `status is JobStatus(...)`.
This is a model-derived candidate for a Parsl regression test, not a claim that the external source
has already been patched.

`ParslProviderStatusBatch.tla` models the scheduler polling boundary more closely. Active jobs
are queried in bounded batches; a failed or timed-out scheduler command leaves the previous
provider status map unchanged, while a successful poll applies all reported states atomically
and maps jobs absent from the scheduler output to `COMPLETED` (the current Slurm fallback rule).
The finite configuration bounds the number of successful polls while retaining all status
translation branches. This follows the batching and `execute_wait` behavior in
[`cluster_provider.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/providers/cluster_provider.py)
and [`slurm.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/providers/slurm/slurm.py).

`ParslProviderExecutorBridge.tla` connects those provider observations to executor admission.
It models a pilot block moving from `pending` to `running`, manager registration, task submission,
unknown status without immediate teardown, and terminal provider observations from either the
pre-manager `pending` phase or the post-registration phase. Terminal observations revoke manager
and worker capacity and account for queued/running work as lost. This cross-component model is
intentionally small so a provider/executor inconsistency produces a short TLC trace.

`ParslHeartbeatProvider.tla` adds the time boundary between provider status and HTEX manager
health. A transient provider `unknown` state does not revoke an otherwise healthy manager;
heartbeat age is advanced separately, and crossing the threshold removes the manager and marks
its in-flight tasks lost. Provider terminal states still revoke the block independently. This
matches the interchange's `last_heartbeat` update and expiry path in
[`high_throughput/interchange.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/executors/high_throughput/interchange.py).

`ParslResultRace.tla` focuses on DFK callback ordering. It separates a physical attempt's
failure/success message from delivery of that message, permits a late success after a failure
callback has already selected a retry, and requires that only the current attempt can resolve the
logical Future. Older or duplicate callbacks are consumed as stale. This mirrors the retry and
Future-completion branches in [`dflow.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/dataflow/dflow.py).

`ParslJoinCallbackRace.tla` refines `join_app` at callback level. An inner completion callback
may run while another inner Future is still unresolved; that callback returns without finalizing.
The callback for the final done Future performs the all-done check under a modeled join lock.
Failures therefore propagate as `JoinError` only after every selected Future is done, and duplicate
callbacks after outer termination are harmless. Ordered list results remain tied to input order.

`ParslJoinMemoData.tla` connects that callback protocol to two real DFK boundaries: a memoization
hit returns an already-completed Future without launching an executor attempt, while a file-valued
`DataFuture` remains unresolved through staging until data readiness is published. The outer join
cannot finalize before the staged file is ready, and its aggregate still preserves input order.
This follows the `BasicMemoizer.check_memo` and `DataFuture.parent_callback` contracts in
[`memoization.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/dataflow/memoization.py)
and [`futures.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/app/futures.py).

`ParslJoinMonitoring.tla` connects the resulting outer join status to the asynchronous monitoring
radio/database model. It emits versioned `joining`, `succeeded`, and `failed` events, permits radio
reordering and write failure/retry, and prevents an older/non-terminal event from overwriting a
terminal database row. The join/data invariants remain active while monitoring delivery is delayed.
The event categories correspond to the task-information channel in
[`monitoring/message_type.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/monitoring/message_type.py)
and the sender/receiver boundary in [`monitoring/radios/base.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/monitoring/radios/base.py).

`ParslResourceAdmission.tla` models concrete WorkQueue-style resource admission. It checks the
accepted resource-specification fields (`cores`, `memory`, `disk`, `gpus`, priority, and runtime),
the rule that cores/memory/disk are supplied together when `autolabel=False`, and worker-level
capacity accounting while tasks wait, dispatch, and complete. The companion autolabel
configuration checks that a partial specification is admitted only when autolabeling is enabled.
This follows the validation and task tuple construction in
[`workqueue/executor.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/executors/workqueue/executor.py).

`ParslResourceScaling.tla` connects resource demand to provider block scaling. A task whose core
demand exceeds current block capacity causes a pending block request; allocation success adds
capacity, allocation failure rolls back only the pending request, and a later strategy step may
retry. Dispatch remains guarded by aggregate core capacity, and scale-in cannot remove the
minimum block floor. This combines the resource-aware admission abstraction with the slot-pressure
rules in [`jobs/strategy.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/jobs/strategy.py)
and block request handling in [`executors/status_handling.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/executors/status_handling.py).

`ParslPollerBadState.tla` models the ordering in `JobStatusPoller.poll`: provider status is
refreshed first, the error handler counts `FAILED`/`MISSING` blocks, and strategy scaling is
available only while the executor is healthy. Reaching the initial-block failure threshold puts
the executor in bad state, fails outstanding tasks, and prevents later task admission or scale-out.
The abstraction follows [`jobs/job_status_poller.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/jobs/job_status_poller.py),
[`jobs/error_handlers.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/jobs/error_handlers.py),
and [`executors/status_handling.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/executors/status_handling.py).

`ParslSerializationWire.tla` models the concrete `pack_apply_message` wire shape: callable,
args, and kwargs are serialized separately; callable/data serializer identifiers are placed before
each body; decimal length prefixes frame the buffers in order; and unpack/decode cannot dispatch
until all three buffers are valid. It also models serializer failure and corrupt-frame rejection.
The configurations use the current identifiers (`C2` for callable dill and `02` for data dill)
from [`serialize/facade.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/serialize/facade.py)
and [`serialize/concretes.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/serialize/concretes.py).

`ParslSerializationZMQBridge.tla` connects those framed buffers to a bounded ZMQ-like route.
Task and result messages carry an attempt id and serializer token; send/receive can drop, duplicate,
or misroute a message; decode is required before task dispatch; and only a result for the current
attempt can resolve the Future. A result from an old attempt is explicitly stale even after a
valid decode. This combines the concrete serialization facade with the ROUTER/DEALER-style
correlation already abstracted in `ParslZMQ.tla`.

`ParslHtexResultQueue.tla` probes the concrete HTEX result thread. It models successful result
decoding, exception decoding, malformed result messages, duplicate task IDs, and the special
interchange-failure message. The actual configuration reproduces an orphaned Future when a
malformed message is popped from `tasks` before validation; the fixed configuration keeps the
Future terminal and ignores duplicates. This follows
[`high_throughput/executor.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/executors/high_throughput/executor.py)
around `_result_queue_worker` and `submit_payload`.

`ParslHtexVersionMismatch.tla` models registration rejection when manager Python/Parsl versions
do not match. The actual configuration exposes a race: the interchange has already set its kill
event and queued the `task_id=-1` fatal result, but the executor result thread has not yet set
`bad_state_is_set`; `submit_payload` can therefore accept another task in that window. The fixed
configuration adds an admission guard for the closed interchange/pending-fatal state. This follows
the registration branch and fatal result construction in
[`interchange.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/executors/high_throughput/interchange.py)
and the admission check in
[`high_throughput/executor.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/executors/high_throughput/executor.py).

`ParslHtexDispatchPriority.tla` models the HTEX pending-task queue and manager dispatch boundary.
It uses the current `SortedList` ordering (`-priority`, then `-task_id`), dispatches only while a
manager has capacity and is not draining, releases capacity on completion, and clears in-flight
work when the manager fails. This follows the queue insertion, `get_tasks`, and
`process_tasks_to_send` paths in
[`interchange.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/executors/high_throughput/interchange.py).

Each logical task also has two abstract serialization capabilities: membership in
`CALLABLE_SERIALIZABLE` represents whether the Python function can be encoded, while
membership in `PAYLOAD_SERIALIZABLE` represents whether its arguments or closure object graph
can be encoded. `SerializeAttempt` requires both. If either capability is absent,
`SerializationFailure` rejects the attempt before a worker is assigned and applies the normal
retry bound.

The finite object-graph refinement adds `OBJECTS`, `TASK_OBJECTS`, `SERIALIZABLE_OBJECTS`, and
`OBJECT_EDGES`. A task's object set stands for its function object, arguments, and closure
contents; two bounded levels of referenced children are checked. Thus a task can have a
serializable callable and top-level arguments but still fail because a nested closure object is
not serializable. `ParslNestedSerialization.cfg` exercises that grandchild failure path. This is
still symbolic rather than an execution of Python `pickle`, but it makes the failure cause
explicit and gives TLC a concrete counterexample vocabulary.

Result encoding is checked separately through the optional symbolic object `task:result`. If
that object (or its bounded descendants) is not serializable, `SerializeResult` is disabled and
`ResultSerializationFailure` releases the worker, drops the result envelope, and follows the
normal retry/rejection path. `ParslResultSerializationFailure.cfg` exercises this post-execution
failure.

File-oriented data readiness is represented by `dataState`:

```text
unavailable -> staging -> available -> stageout_chunk1 -> stageout_chunk2 -> transferred
              \-> staging_corrupt -> staging
                                      \-> stageout_chunk1_corrupt
                                      \-> stageout_chunk2_corrupt
```

`BeginStaging`/`FinishStaging` model input stage-in before dependency release. `CorruptStaging`
and `RepairStaging` model an input transfer that is damaged before it becomes available. For tasks in
`FILE_OUTPUTS`, `BeginStageOut` starts output transfer, `TransferOutputChunk` advances the first
chunk, and `FinishStageOut` commits the second chunk as `transferred`. This prevents a model
execution from claiming that a file is ready before all transfer stages complete. The token stands
for file contents and transfer completion without enumerating bytes, paths, or a particular staging provider. The checked
configurations use task `C` as one representative output file to keep the finite state space
small while still exercising both directions of the data path.

The corruption refinement records which chunk was damaged: corruption of the first or second
chunk enters a chunk-specific state, and repair resumes from that chunk rather than silently
marking the whole file transferred. This is a symbolic content/checksum abstraction, not a byte-
for-byte file-system simulation.

The file-content refinement defines a deterministic symbolic token `task:content` for each
logical output task. `FinishStageOut` therefore represents transfer of that task's content token,
not just a boolean readiness flag. `FileContentSafety` checks that a transferred output has the
correct logical token and that stage-out is only associated with a completed result. The token
stands for bytes or a checksum at this level; the two chunk states provide a bounded transfer
protocol, while later refinements can replace them with checksums and richer corruption transitions.

## What is and is not modeled

The current model covers the major control-flow effects represented in the paper's DFK,
executor, interchange/manager, provider, and dataflow architecture. It does **not** simulate
every implementation detail or every component in full fidelity.

Deliberately abstracted away are ZMQ byte messages, serialized Python objects, callable
contents, real filenames, wall-clock time, heartbeat timing, database schema, monitoring
transport, and the exact behavior of every alternative executor/provider. Data staging is
represented only by `unavailable/staging/available`. The model therefore checks protocol
properties of a bounded abstraction; it is not a proof that the complete Parsl implementation
is correct.

The submission path now exposes an abstract message lifecycle: `SerializeAttempt` represents
encoding the task payload, `SendAttempt` and `ReceiveAttempt` represent transport across the
interchange boundary, and `DecodeAttempt` represents reconstructing the work item. Dispatch to
a worker is enabled only after decoding succeeds. Payload bytes and Python object contents remain
abstract; this stage checks ordering and failure-safe handoff rather than ZMQ or pickle behavior.

The wire lifecycle is represented explicitly by `taskWireState` and `resultWireState` for every
physical attempt. Each side has the finite states `none`, `queued`, `sent`, `received`,
`acknowledged`, and `consumed`, while `taskEnvelope` and `resultEnvelope` record whether the serialized envelope is
`valid` or `invalid`. `MessageSafety` checks that a queued/sent/received envelope agrees with the
corresponding attempt state. This is a protocol-level ZMQ abstraction: it models the two message
directions and their ordering without enumerating sockets, byte buffers, or multipart frames.
The result direction additionally uses `acknowledged` between `received` and `consumed`, modeling
a receiver-side consume acknowledgement before decode without claiming a particular ZMQ wire
ack implementation.
`ProtocolProgress` gives ACK transitions their own strong-fairness obligation; duplicate/discard
traffic alone is not treated as useful progress, preventing a livelock from starving decode.
The next refinement can add bounded drops, duplicate deliveries, and symbolic object graphs
without changing the logical-task/physical-attempt boundary.

`DropTaskMessage` and `DropResultMessage` add a bounded network-loss hypothesis. A dropped task
envelope never reaches a worker; a dropped result envelope releases the worker and turns the
current attempt into `lost`, after which the ordinary retry or rejection path applies. The
message-loss configuration checks that a dropped or invalid envelope cannot resolve a Future,
leak a worker binding, or bypass the retry bound.

`DuplicateTaskMessage` and `DuplicateResultMessage` model a receiver observing a second copy
of an already received envelope. The duplicate must pass through an explicit discard action
before the normal decode action can continue; it cannot create a second logical completion.

`MisrouteAttempt` models decoded work offered to a manager belonging to the wrong executor.
The message is rejected and the attempt follows the lost/retry path instead of executing on the
wrong manager.

`MisrouteResult` applies the same check on the return path: a result envelope claiming a
different executor source is rejected before `AttemptSuccess` can resolve the Future.

The result path has the same shape after worker execution: `SerializeResult`, `SendResult`,
`ReceiveResult`, and `DecodeResult` must occur before `AttemptSuccess` resolves the Future. A
worker or executor failure can still replace an in-flight result with a retry, so a result from
the old attempt remains eligible only for the explicit stale-result transition.

## Join applications

Tasks in `JOIN_TASKS` model Parsl `join_app` tasks. Their first successful physical attempt
returns a join handle rather than resolving the outer Future: the logical task enters
`joining`, and `JoinObserve` records completion of each inner Future listed in `JOIN_DEPS`.
`JoinComplete` resolves the outer Future only after every inner Future succeeds; with failures
enabled, `JoinFailure` propagates a rejected inner Future to the outer task. This keeps the
outer logical task separate from the physical attempt that produced the list of inner Futures,
matching `DataFlowKernel.handle_exec_update` and `handle_join_update`.
Successful joins carry a distinct symbolic `join-result` output marker, recording that the outer
value is an aggregation rather than an ordinary task result while remaining independent of the
concrete Python list/dict shape.
`JoinHandleSafety` also keeps the intermediate `join-handle` distinct from the final aggregate.
`JoinFailureSafety` requires a failed outer join to have a rejected inner Future; an arbitrary
outer rejection cannot masquerade as inner-Future propagation.

`JOIN_INVALID` models a join app whose callable returns neither a Future nor a list of Futures.
The physical attempt may finish successfully, but join unwrapping fails deterministically and
the outer Future becomes rejected. `ParslJoinInvalid.cfg` checks this TypeError-like branch
without allowing it to masquerade as a successful join.

## Logical time and heartbeat failures

The model uses a bounded logical clock rather than wall-clock timestamps. `Tick` advances the
clock, `Heartbeat` records the latest manager heartbeat for a worker, and `StartAttemptTimed`
records an attempt start time. `WorkerFailure` can therefore be enabled by a heartbeat age beyond
`HEARTBEAT_TIMEOUT`, while `AttemptTimeout` can be enabled by an attempt age beyond
`TASK_TIMEOUT`. A timeout on the final retry now rejects the Future and terminates the task rather
than leaving it indefinitely running. The full workflow configurations set `MAX_TIME = 0` to avoid combining every
workflow interleaving with clock values; `ParslTime.cfg` is a deliberately tiny one-task model
that explores the time and timeout transitions with `MAX_TIME = 1`.
`ParslTimeoutTerminal.cfg` uses `MAX_RETRIES = 0` to check the terminal-timeout path directly.
For an executor with multiple manager workers, `IdleManagerTimeout` removes only the expired
manager's block; remaining managers and capacity stay active until the final expiry.

Monitoring is modeled as `monitoringState`, a per-task database record containing the last
persisted status and a monotonic write `version`. `PublishMonitor` may lag behind the logical
task state, matching asynchronous monitoring delivery, but `MonitoringConsistency` forbids a
persisted terminal success, memoized state, or failure from appearing before the corresponding
logical outcome. `MonitoringDatabaseSafety` ensures the initial `none` record has version zero
and every published update advances its version. As with time, the full workflow configurations
disable event expansion and `ParslMonitoring.cfg` is the focused one-task exploration. A bounded
`write_failed` state represents a transient database write error; recovery must publish the
current logical view again rather than inventing a terminal status.

Executor/provider submission is separated into two hypotheses. `SubmitAttempt` is allowed only
for an executor in `SUBMITTABLE_EXECUTORS`, representing an executor whose bad-state check and
submit path accept work. `SubmitFailure` represents a provider block that exists while the
executor rejects new submissions; it creates a failed physical attempt before any worker is
bound and follows the normal retry/rejection path. `ParslSubmitFailure.cfg` explores this race
with a one-task executor whose submit set is empty.

Provider block failure is modeled separately from allocation failure. `ProviderFailure` represents
an already-active block terminating while idle; it marks the provider and executor unavailable and
clears the desired and active block counts. `ProviderExecutorConsistency` checks that an active
provider implies an up executor with a positive block count, and that a failed provider has no
remaining target or active blocks. Recovery requests increment the target again before a new
allocation can become active.

## TLC verification

The checked configurations use three logical tasks (`A`, `B`, `C`), two executors, two
workers, one retry, and one block per executor. Java and `tla2tools.jar` are required.

```bash
java -cp tla2tools.jar tlc2.TLC -deadlock -config parsl.cfg parsl.tla
java -cp tla2tools.jar tlc2.TLC -deadlock -config ParslMemo.cfg ParslAbstract.tla
java -cp tla2tools.jar tlc2.TLC -deadlock -config ParslSerializationFailure.cfg ParslAbstract.tla
java -cp tla2tools.jar tlc2.TLC -config ParslNoFailures.cfg ParslAbstract.tla
java -cp tla2tools.jar tlc2.TLC -config ParslTime.cfg ParslAbstract.tla
java -cp tla2tools.jar tlc2.TLC -deadlock -config ParslMonitoring.cfg ParslAbstract.tla
java -cp tla2tools.jar tlc2.TLC -deadlock -config ParslSubmitFailure.cfg ParslAbstract.tla
java -cp tla2tools.jar tlc2.TLC -deadlock -config ParslProviderFailure.cfg ParslAbstract.tla
java -cp tla2tools.jar tlc2.TLC -config ParslJoin.cfg ParslAbstract.tla
java -cp tla2tools.jar tlc2.TLC -deadlock -config ParslJoinSafety.cfg ParslAbstract.tla
java -cp tla2tools.jar tlc2.TLC -deadlock -config ParslJoinInvalid.cfg ParslAbstract.tla
java -cp tla2tools.jar tlc2.TLC -deadlock -config ParslRegistration.cfg ParslAbstract.tla
java -cp tla2tools.jar tlc2.TLC -deadlock -config ParslRegistrationFailure.cfg ParslAbstract.tla
java -cp tla2tools.jar tlc2.TLC -deadlock -config ParslIdleManagerTimeout.cfg ParslAbstract.tla
java -cp tla2tools.jar tlc2.TLC -deadlock -config ParslExecutorDrain.cfg ParslAbstract.tla
java -cp tla2tools.jar tlc2.TLC -deadlock -config ParslMisroute.cfg ParslAbstract.tla
java -cp tla2tools.jar tlc2.TLC -deadlock -config ParslResultMisroute.cfg ParslAbstract.tla
java -cp tla2tools.jar tlc2.TLC -deadlock -config ParslMessaging.cfg ParslAbstract.tla
java -cp tla2tools.jar tlc2.TLC -deadlock -config ParslMessageLoss.cfg ParslAbstract.tla
java -cp tla2tools.jar tlc2.TLC -deadlock -config ParslMessageDuplicate.cfg ParslAbstract.tla
java -cp tla2tools.jar tlc2.TLC -deadlock -config ParslFileContent.cfg ParslAbstract.tla
java -cp tla2tools.jar tlc2.TLC -deadlock -config ParslFileCorruptionSmall.cfg ParslAbstract.tla
java -cp tla2tools.jar tlc2.TLC -deadlock -config ParslNestedSerialization.cfg ParslAbstract.tla
java -cp tla2tools.jar tlc2.TLC -config ParslStrategy.cfg ParslStrategy.tla
java -cp tla2tools.jar tlc2.TLC -config ParslZMQ.cfg ParslZMQ.tla
java -cp tla2tools.jar tlc2.TLC -config ParslPython.cfg ParslPython.tla
java -cp tla2tools.jar tlc2.TLC -config ParslPythonFailure.cfg ParslPython.tla
java -cp tla2tools.jar tlc2.TLC -config ParslFileBytes.cfg ParslFileBytes.tla
java -cp tla2tools.jar tlc2.TLC -config ParslStageOutFuture.cfg ParslStageOutFuture.tla
java -cp tla2tools.jar tlc2.TLC -config ParslStageOutInTask.cfg ParslStageOutFuture.tla
java -cp tla2tools.jar tlc2.TLC -config ParslStageOutNone.cfg ParslStageOutFuture.tla
java -cp tla2tools.jar tlc2.TLC -config ParslClock.cfg ParslClock.tla
java -cp tla2tools.jar tlc2.TLC -config ParslClockTerminal.cfg ParslClock.tla
java -cp tla2tools.jar tlc2.TLC -config ParslHeartbeatBoundary.cfg ParslHeartbeatBoundary.tla
java -cp tla2tools.jar tlc2.TLC -config ParslMonitoringDB.cfg ParslMonitoringDB.tla
java -cp tla2tools.jar tlc2.TLC -config ParslMonitoringDBReorder.cfg ParslMonitoringDB.tla
java -cp tla2tools.jar tlc2.TLC -config ParslMonitoringDeferred.cfg ParslMonitoringDeferred.tla
java -cp tla2tools.jar tlc2.TLC -config ParslMonitoringDBInsert.cfg ParslMonitoringDBInsert.tla
java -cp tla2tools.jar tlc2.TLC -config ParslMonitoringDBInsertFixed.cfg ParslMonitoringDBInsert.tla
java -cp tla2tools.jar tlc2.TLC -config ParslMonitoringDBInsertPresent.cfg ParslMonitoringDBInsert.tla
java -cp tla2tools.jar tlc2.TLC -config ParslPBSProSubmit.cfg ParslPBSProSubmit.tla
java -cp tla2tools.jar tlc2.TLC -config ParslPBSProSubmitFixed.cfg ParslPBSProSubmit.tla
java -cp tla2tools.jar tlc2.TLC -config ParslPBSProSubmitPresent.cfg ParslPBSProSubmit.tla
java -cp tla2tools.jar tlc2.TLC -config ParslTorqueStatus.cfg ParslTorqueStatus.tla
java -cp tla2tools.jar tlc2.TLC -config ParslTorqueStatusFixed.cfg ParslTorqueStatus.tla
java -cp tla2tools.jar tlc2.TLC -config ParslTorqueStatusPresent.cfg ParslTorqueStatus.tla
java -cp tla2tools.jar tlc2.TLC -config ParslCondorStatus.cfg ParslCondorStatus.tla
java -cp tla2tools.jar tlc2.TLC -config ParslCondorStatusFixed.cfg ParslCondorStatus.tla
java -cp tla2tools.jar tlc2.TLC -config ParslCondorStatusPresent.cfg ParslCondorStatus.tla
java -cp tla2tools.jar tlc2.TLC -config ParslExecutorProvider.cfg ParslExecutorProvider.tla
java -cp tla2tools.jar tlc2.TLC -config ParslJoinApp.cfg ParslJoinApp.tla
java -cp tla2tools.jar tlc2.TLC -config ParslJoinRetry.cfg ParslJoinRetry.tla
java -cp tla2tools.jar tlc2.TLC -config ParslNestedJoin.cfg ParslNestedJoin.tla
java -cp tla2tools.jar tlc2.TLC -config ParslJoinDuplicates.cfg ParslJoinDuplicates.tla
java -cp tla2tools.jar tlc2.TLC -config ParslJoinMixedList.cfg ParslJoinMixedList.tla
java -cp tla2tools.jar tlc2.TLC -config ParslJoinMixedListValid.cfg ParslJoinMixedList.tla
java -cp tla2tools.jar tlc2.TLC -config ParslTaskTransport.cfg ParslTaskTransport.tla
java -cp tla2tools.jar tlc2.TLC -config ParslTaskTransportFailure.cfg ParslTaskTransport.tla
java -cp tla2tools.jar tlc2.TLC -config ParslProviderPolling.cfg ParslProviderPolling.tla
java -cp tla2tools.jar tlc2.TLC -depth 10 -config ParslExecutorKinds.cfg ParslExecutorKinds.tla
java -cp tla2tools.jar tlc2.TLC -config ParslExecutorShutdown.cfg ParslExecutorShutdown.tla
java -cp tla2tools.jar tlc2.TLC -config ParslWorkQueueResults.cfg ParslWorkQueueResults.tla
java -cp tla2tools.jar tlc2.TLC -config ParslFluxResultFixed.cfg ParslFluxResult.tla
java -cp tla2tools.jar tlc2.TLC -config ParslTaskVineResults.cfg ParslTaskVineResults.tla
java -cp tla2tools.jar tlc2.TLC -config ParslRadicalPilotResultsFixed.cfg ParslRadicalPilotResults.tla
java -cp tla2tools.jar tlc2.TLC -config ParslGlobusComputeConfigFixed.cfg ParslGlobusComputeConfig.tla
java -cp tla2tools.jar tlc2.TLC -config ParslProviderKinds.cfg ParslProviderKinds.tla
java -cp tla2tools.jar tlc2.TLC -config ParslAWSProviderStatus.cfg ParslAWSProviderStatus.tla
java -cp tla2tools.jar tlc2.TLC -config ParslAWSProviderStatusFixed.cfg ParslAWSProviderStatus.tla
java -cp tla2tools.jar tlc2.TLC -config ParslAWSProviderStatusPresent.cfg ParslAWSProviderStatus.tla
java -cp tla2tools.jar tlc2.TLC -config ParslProviderStatusBatch.cfg ParslProviderStatusBatch.tla
java -cp tla2tools.jar tlc2.TLC -config ParslKubernetesPollingFixed.cfg ParslKubernetesPolling.tla
java -cp tla2tools.jar tlc2.TLC -config ParslProviderExecutorBridge.cfg ParslProviderExecutorBridge.tla
java -cp tla2tools.jar tlc2.TLC -config ParslHeartbeatProvider.cfg ParslHeartbeatProvider.tla
java -cp tla2tools.jar tlc2.TLC -config ParslResultRace.cfg ParslResultRace.tla
java -cp tla2tools.jar tlc2.TLC -config ParslJoinCallbackRace.cfg ParslJoinCallbackRace.tla
java -cp tla2tools.jar tlc2.TLC -config ParslJoinMemoData.cfg ParslJoinMemoData.tla
java -cp tla2tools.jar tlc2.TLC -config ParslJoinMonitoring.cfg ParslJoinMonitoring.tla
java -cp tla2tools.jar tlc2.TLC -config ParslResourceAdmission.cfg ParslResourceAdmission.tla
java -cp tla2tools.jar tlc2.TLC -config ParslResourceAdmissionAutolabel.cfg ParslResourceAdmission.tla
java -cp tla2tools.jar tlc2.TLC -config ParslResourceScaling.cfg ParslResourceScaling.tla
java -cp tla2tools.jar tlc2.TLC -config ParslPollerBadState.cfg ParslPollerBadState.tla
java -cp tla2tools.jar tlc2.TLC -config ParslSerializationWire.cfg ParslSerializationWire.tla
java -cp tla2tools.jar tlc2.TLC -config ParslSerializationWireFailure.cfg ParslSerializationWire.tla
java -cp tla2tools.jar tlc2.TLC -config ParslSerializationZMQBridge.cfg ParslSerializationZMQBridge.tla
java -cp tla2tools.jar tlc2.TLC -config ParslHtexResultQueueFixed.cfg ParslHtexResultQueue.tla
java -cp tla2tools.jar tlc2.TLC -config ParslHtexVersionMismatchFixed.cfg ParslHtexVersionMismatch.tla
java -cp tla2tools.jar tlc2.TLC -config ParslHtexDispatchPriority.cfg ParslHtexDispatchPriority.tla
java -cp tla2tools.jar tlc2.TLC -config ParslMPISpecFixed.cfg ParslMPISpec.tla
```

The first configuration checks `TypeOK`, dependency safety, terminal-state stability,
retry bounds, worker capacity/binding, valid assignments, executor availability for running
attempts, attempt identity, Future result consistency, stale-result safety, serialization
safety, data readiness, file-transfer safety, symbolic file-content identity, and time consistency.

The purpose of these checks is bug finding, not only documentation. A model action is a small
executable hypothesis about a Parsl transition; if an implementation change would permit a task
to run before its data is ready, accept an old result, exceed its retry bound, or run after a
heartbeat/timeout failure, the corresponding invariant should produce a finite TLC counterexample
trace. Each trace can then be mapped back to the source locations in the table below and used as
a focused test or as evidence that the abstraction is missing a guard.

Measured with TLC 2.19 and Java 17 on 2026-09-28:

- `ParslAbstract.cfg`: 6,074,516 states generated, 911,791 distinct states, depth 87;
  all invariants passed.
- `ParslMemo.cfg`: 557,440 states generated, 81,233 distinct states, depth 65; all invariants passed.
- `ParslSerializationFailure.cfg`: 3,901,406 states generated, 569,651 distinct states, depth 69;
  all safety invariants passed, including the pre-dispatch serialization-failure path.
- `ParslResultSerializationFailure.cfg`: 2,776 states generated, 600 distinct states, depth 28;
  an unencodable worker return failed after execution without resolving the Future.
- `ParslNestedSerialization.cfg`: 559 states generated, 118 distinct states, depth 16;
  a non-serializable grandchild object failed before dispatch while object-graph safety held.
- `ParslNoFailures.cfg`: 21,760 states generated, 3,969 distinct states, depth 60;
  `EventuallySettled` passed under `WF_vars(NextCore)`.
- `ParslTime.cfg`: 690 states generated, 198 distinct states, depth 36;
  `EventuallySettled` passed with logical ticking and timeout transitions enabled.
- `ParslTimeoutTerminal.cfg`: 859 states generated, 240 distinct states, depth 23;
  a final-attempt timeout rejected the Future and still satisfied `EventuallySettled`.
- `ParslMonitoring.cfg`: 167,482 states generated, 25,066 distinct states, depth 43;
  all monitoring consistency invariants passed.
- `ParslSubmitFailure.cfg`: 185 states generated, 45 distinct states, depth 12;
  submit rejection remained pre-dispatch and all retry/result invariants passed.
- `ParslProviderFailure.cfg`: 6,868 states generated, 1,280 distinct states, depth 40;
  provider failure, recovery request, and block-count consistency all passed.
- `ParslScaleIn.cfg`: 54,755 states generated, 7,668 distinct states, depth 37;
  multi-block scale-out, partial scale-in, and failed secondary allocation preserved provider
  block/target consistency.
- `ParslMinBlocks.cfg`: 66,423 states generated, 9,612 distinct states, depth 37;
  scale-in could not remove the configured minimum one block.
- `ParslStrategy.cfg`: 327 states generated, 114 distinct states, depth 13;
  slot-pressure scale-out, idle-timer handling, minimum/maximum block bounds, and task-pressure
  safety all passed in the focused strategy model.
- `ParslZMQ.cfg`: 33,321 states generated, 6,216 distinct states, depth 35;
  multipart encoding order, bounded queues, disconnect/drop, route validation, duplicate discard,
  correlation, and acknowledgement safety all passed in the focused transport model.
- `ParslPython.cfg`: 4,415 states generated, 1,035 distinct states, depth 17;
  callable roots, globals/defaults/closure traversal, symbolic pickle round-trip, and payload
  reconstruction safety passed.
- `ParslPythonFailure.cfg`: 4,415 states generated, 1,035 distinct states, depth 18;
  a non-serializable nested closure object failed before encoding completed or a payload token was
  published.
- `ParslFileBytes.cfg`: 630 states generated, 201 distinct states, depth 14;
  chunk checksums, corruption repair, stale source-version detection, and atomic stage-in/stage-out
  publication all passed.
- `ParslStageOutFuture.cfg`: 47 states generated, 23 distinct states, depth 10; separate
  stage-out completion, failure/retry, output publication, and dependent-task gating passed.
- `ParslStageOutInTask.cfg`: 14 states generated, 7 distinct states, depth 5; in-task transfer
  publication is tied to application completion.
- `ParslStageOutNone.cfg`: 14 states generated, 7 distinct states, depth 5; the no-staging path
  correctly makes the application Future the output dependency.
- `ParslClock.cfg`: 179,383 states generated, 37,788 distinct states, depth 21;
  wall-clock bounds, heartbeat delivery/drop/expiry, attempt deadlines, timeout-or-manager-loss
  retry selection, and stale late-result handling all passed.
- `ParslClockTerminal.cfg`: 6,440 states generated, 1,574 distinct states, depth 13;
  terminal timeout rejection with no remaining retry passed the same time and result invariants.
- `ParslHeartbeatBoundary.cfg`: 316 states generated, 93 distinct states, depth 10;
  strict heartbeat threshold, heartbeat reset at the boundary, manager expiry, and in-flight
  failure accounting all passed.
- `ParslMonitoringDB.cfg`: 757 states generated, 291 distinct states, depth 11;
  asynchronous write failure/retry, version monotonicity, database consistency, and terminal
  record safety passed.
- `ParslMonitoringDBReorder.cfg`: 527 states generated, 206 distinct states, depth 9;
  radio queue reordering and stale-event suppression passed with the same invariants.
- `ParslMonitoringDeferred.cfg`: 36 states generated, 16 distinct states, depth 6;
  deferred first-message replay, duplicate-first replacement/discard, try-before-status foreign
  key ordering, and bounded monitoring cleanup all passed.
- `ParslMonitoringDBInsert.cfg`: expected counterexample, 4 states generated and 3 distinct
  states at depth 3; a duplicate STATUS key reaches the current generic-exception return path,
  so the event is dropped while the pre-existing row remains.
- `ParslMonitoringDBInsertFixed.cfg`: 6 states generated, 3 distinct states, depth 3; an
  idempotent duplicate handler preserves the row and satisfies `DuplicatePersistence`.
- `ParslMonitoringDBInsertPresent.cfg`: 6 states generated, 3 distinct states, depth 3; a
  non-duplicate STATUS insert passes the same invariants.
- `ParslPBSProSubmit.cfg`: expected counterexample, 2 states generated and 2 distinct states at
  depth 2; successful empty `qsub` output returns `None` without registering a resource.
- `ParslPBSProSubmitFixed.cfg`: 4 states generated, 2 distinct states, depth 2; empty output is
  rejected instead of being reported as a successful submission.
- `ParslPBSProSubmitPresent.cfg`: 4 states generated, 2 distinct states, depth 2; a normal job
  identifier satisfies the submission contract.
- `ParslTorqueStatus.cfg`: expected counterexample, 4 states generated and 3 distinct states at
  depth 3; a foreign qstat line reaches the direct resource-map lookup crash.
- `ParslTorqueStatusFixed.cfg`: 6 states generated, 3 distinct states, depth 3; foreign lines
  are ignored and known-job status remains safe.
- `ParslTorqueStatusPresent.cfg`: 6 states generated, 3 distinct states, depth 3; a known qstat
  line updates the tracked job to completed.
- `ParslCondorStatus.cfg`: expected counterexample, 4 states generated and 3 distinct states at
  depth 3; a malformed `condor_q` line reaches the unchecked two-field indexing path.
- `ParslCondorStatusFixed.cfg`: 6 states generated, 3 distinct states, depth 3; short lines are
  ignored without changing the known resource status.
- `ParslCondorStatusPresent.cfg`: 6 states generated, 3 distinct states, depth 3; a valid
  two-field status line updates the tracked job.

The Condor status counterexample is also checked against the current Python source with a
deterministic scheduler stub (no Condor installation is required):

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_condor_status_malformed.py -v
```

The runtime probe confirms that a one-field `condor_q` line raises `IndexError`, while a valid
two-field line updates the tracked resource.

The Torque foreign-job counterexample has the same kind of source-level runtime probe:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_torque_status_foreign.py -v
```

It confirms that an unregistered qstat job raises `KeyError`, while a known job line updates the
tracked resource.

The monitoring STATUS insert path is checked against a real temporary SQLite database:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_monitoring_db_runtime.py -v
```

The test confirms both the duplicate primary-key `IntegrityError` and the current
`DatabaseManager._insert` behavior that catches, rolls back, and silently returns from that
error, leaving only the original STATUS row.

The real serialization facade is also exercised with the same callable/object boundary used by
the wire models:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_serialization_runtime.py -v
```

The tests verify closure round-trip behavior, the `C2` callable and `02` data headers, three-part
apply-message ordering, and rejection of an unserializable argument before a message is packed.
They also verify closure snapshot semantics and nested argument-object graph round trips.

The local zip staging implementation is exercised against actual bytes as well:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_zip_file_transfer_runtime.py -v
```

This verifies stage-out archive creation and source cleanup, stage-in byte preservation, failure
on a corrupt archive before output publication, and the local-file scheme gate in
`NoOpFileStaging`.

The ZMQ transport and serialization boundary is exercised with real in-process ROUTER/DEALER
sockets:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_zmq_serialization_runtime.py -v
```

The probe checks multipart frame count, route identity preservation, Parsl apply-message
deserialization, task execution, and an ACK sent back over the routed socket.

All runtime probes can be run together as an integration baseline:

```bash
/tmp/parsl-venv/bin/python -m unittest discover -s tests -p 'test_*runtime.py' -v
```

The current baseline runs 37 tests covering serialization, ZMQ, files/DataFutures, retry and
timeouts, heartbeat expiry, monitoring SQLite writes, join semantics, memoization, executor
shutdown, and provider status/submit paths.

The concrete `join_app` protocol is exercised with a real local thread executor:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_join_runtime.py -v
```

This verifies single-Future propagation, ordered list results with duplicate Future references,
empty-list completion without callbacks, and `JoinError` propagation from a failed inner app.
It also checks nested join propagation and rejection of both scalar and mixed-list join returns.

Physical retry and Python app timeout behavior are checked against a local thread executor:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_retry_timeout_runtime.py -v
```

The tests confirm a first-attempt failure is followed by a second physical attempt, and that a
task exceeding its `walltime` completes with `AppTimeout` when no retries remain.

Memoization and cached-result dependency propagation are exercised with a real local executor:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_memoization_runtime.py -v
```

The probe confirms duplicate calls execute once, calls with different arguments execute normally,
and a dependent app can consume the memoized Future result.

The LSF provider status parser is exercised with deterministic `bjobs` output:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_lsf_status_runtime.py -v
```

The probe checks foreign-job filtering, unknown-state exposure, and the current missing-job
fallback to `COMPLETED`.

Slurm batched status handling is exercised with deterministic scheduler command results:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_slurm_status_batch_runtime.py -v
```

The tests check that a non-zero scheduler command preserves every previous status and that a
successful batch updates reported jobs while applying the current missing-job `COMPLETED` fallback.

Grid Engine qstat parsing is exercised with deterministic output:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_grid_engine_status_runtime.py -v
```

The probe reproduces the short-line `IndexError` boundary, checks `r` to `RUNNING` translation,
and verifies foreign-job filtering with the missing-job `COMPLETED` fallback.

Azure VM status handling is exercised with a fake compute client:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_azure_status_runtime.py -v
```

The tests check running-state translation, the current `IndexError`-to-`PENDING` path for missing
instance-view status, and propagation of non-index cloud API errors.

Azure VM cancellation is exercised with a fake asynchronous delete client:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_azure_cancel_runtime.py -v
```

The probe checks linger-mode refusal, delete-error rollback, and successful deletion/removal from
the provider's instance list.

Google Compute Engine status handling is exercised with a fake discovery client:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_googlecloud_status_runtime.py -v
```

The probe checks normal `RUNNING` translation, propagation of API errors, and the current
`KeyError` path for an unrecognized provider status.

The corresponding Grid Engine qstat TLA+ model can be checked with:

```bash
java -cp tla2tools.jar tlc2.TLC -config ParslGridEngineStatus.cfg ParslGridEngineStatus.tla
java -cp tla2tools.jar tlc2.TLC -config ParslGridEngineStatusFixed.cfg ParslGridEngineStatus.tla
java -cp tla2tools.jar tlc2.TLC -config ParslGridEngineStatusPresent.cfg ParslGridEngineStatus.tla
```

The current configuration finds an expected depth-3 counterexample (4 generated/3 distinct
states); fixed and valid configurations each generate 6 states/3 distinct states at depth 3.

Torque cancellation outcomes are exercised with deterministic `qdel` results:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_torque_cancel_runtime.py -v
```

The probe records the current distinction between a successful cancellation return and the
provider's `COMPLETED`/exiting resource status, while failed cancellation preserves `RUNNING`.

The corresponding bounded TLA+ cancellation probe can be run with:

```bash
java -cp tla2tools.jar tlc2.TLC -config ParslTorqueCancel.cfg ParslTorqueCancel.tla
java -cp tla2tools.jar tlc2.TLC -config ParslTorqueCancelFixed.cfg ParslTorqueCancel.tla
java -cp tla2tools.jar tlc2.TLC -config ParslTorqueCancelFailure.cfg ParslTorqueCancel.tla
```

`ParslTorqueCancel.cfg` intentionally finds a depth-2 counterexample (2 states generated): a
successful cancel returns `success` while the current provider records `completed`. The fixed
configuration generates 4 states/2 distinct states at depth 2; the failure configuration generates
5 states/2 distinct states at depth 2, and both satisfy the invariants.

The Kubernetes polling regression is also exercised with a mocked Kubernetes API client:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_kubernetes_polling_runtime.py -v
```

The test reproduces the current read-error path that leaves a running job as `RUNNING`, and
checks the normal `Succeeded` pod translation to `COMPLETED`.

The EC2 status boundary is exercised with a fake `describe_instances` client:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_aws_status_runtime.py -v
```

The probe checks the current missing-instance behavior (empty status list and unchanged resource)
and normal `running` state translation.

The PBS Pro submission parser is exercised with a temporary script directory and fake `qsub`
output:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_pbspro_submit_runtime.py -v
```

The tests reproduce the successful-empty-output path returning `None` without a resource and the
normal path registering a pending job id.

The concrete thread executor shutdown and admission contract is exercised directly:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_thread_executor_runtime.py -v
```

The probe checks that accepted work completes before blocking shutdown returns, new submissions
are rejected afterwards, and unsupported resource specifications are rejected at admission.

File/DataFuture readiness is exercised through a real two-task local dataflow:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_datafuture_runtime.py -v
```

The producer writes binary output through a Parsl `File`, and the dependent consumer reads the
same bytes only after the producer has completed.
The same probe also checks that a consumer wired to the producer's output `DataFuture` receives a
`DependencyError` and is never executed when the producer fails.

Ordinary Future dependency propagation is checked separately:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_dependency_runtime.py -v
```

This verifies successful value propagation and failure blocking for non-file task dependencies.

The HTEX heartbeat expiry path is also exercised without opening a real ZMQ socket:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_htex_heartbeat_runtime.py -v
```

The runtime probe checks the strict `elapsed > heartbeat_threshold` boundary and verifies that an
expired manager is deactivated, removed from the scheduling set, and converted into a serialized
failure result for each in-flight task.
- `ParslExecutorProvider.cfg`: 47,002 states generated, 8,221 distinct states, depth 25;
  provider request/success/failure, manager registration, worker slots, submit rejection, executor
  drain/recovery, provider failure, and block-granular scale-in all passed.
- `ParslJoinApp.cfg`: 1,210 states generated, 331 distinct states, depth 10;
  single/list/empty join returns, invalid-return rejection, inner completion/failure observation,
  ordered aggregation, join-handle lifetime, and JoinError propagation all passed.
- `ParslJoinRetry.cfg`: 840 states generated, 258 distinct states, depth 16;
  logical-inner versus physical-attempt separation, retryable inner failure isolation, final failure
  propagation, and ordered final-result aggregation all passed.
- `ParslNestedJoin.cfg`: 414 states generated, 126 distinct states, depth 11;
  nested leaf observation, nested handle lifetime, nested success/failure propagation, and outer
  completion gating all passed.
- `ParslJoinDuplicates.cfg`: 210 states generated, 49 distinct states, depth 7;
  duplicate Future references, callback-position observation, ordered duplicate results, repeated
  failure multiplicity, duplicate callback tolerance, and join-handle cleanup all passed.
- `ParslJoinMixedList.cfg`: 4 states generated, 2 distinct states, depth 2; a mixed Future/non-
  Future list fails immediately without registering callbacks.
- `ParslJoinMixedListValid.cfg`: 76 states generated, 30 distinct states, depth 7; all-Future
  list observation, ordered aggregation, and inner-failure propagation passed.
- `ParslTaskTransport.cfg`: 859 states generated, 288 distinct states, depth 28;
  serialization-before-send, envelope/decode ordering, dispatch admission, worker-loss retry,
  result serialization, correlation, and stale-result safety all passed.
- `ParslTaskTransportFailure.cfg`: 56 states generated, 25 distinct states, depth 13;
  a non-serializable Python object graph was rejected before dispatch on each bounded attempt.
- `ParslProviderPolling.cfg`: 2,861 states generated, 854 distinct states, depth 19;
  provider submit/status/cancel outcomes, unknown-status failure, transient API errors, cancel
  rollback, and block-target consistency all passed.
- `ParslExecutorKinds.cfg`: 50,149,761 states generated, 3,533,824 distinct states, depth 52;
  the bounded depth-10 executor contract run passed provider-free/provider-backed admission,
  manager registration, resource-specification rejection, drain/recovery, and failure cleanup.
- `ParslExecutorShutdown.cfg`: 394,010 states generated, 74,431 distinct states, depth 28;
  shutdown admission rejection, ThreadPool completion-before-stop, WorkQueue collector failure
  cleanup, HTEX interchange closure, and in-flight cleanup all passed.
- `ParslWorkQueueResults.cfg`: 606 states generated, 225 distinct states, depth 9;
  valid-result completion, corrupt/exception/no-result failure mapping, collector shutdown
  cleanup, and terminal-result consistency all passed.
- `ParslFluxResult.cfg`: expected counterexample at depth 2 (54 states generated, 24 distinct);
  cancellation of the underlying Flux future can leave the wrapper Future non-terminal.
- `ParslFluxResultFixed.cfg`: 63 states generated, 26 distinct states, depth 6; valid, missing,
  malformed, and task-exception result mapping plus cancellation propagation all passed.
- `ParslTaskVineResults.cfg`: 56 states generated, 26 distinct states, depth 5; valid-result
  completion, missing/corrupt/exception/no-result failure mapping, and submit-process cleanup of
  outstanding Futures all passed.
- `ParslRadicalPilotResults.cfg`: expected counterexample at depth 2 (73 states generated, 38
  distinct); shutdown can leave a submitted RP task's Parsl Future pending.
- `ParslRadicalPilotResultsFixed.cfg`: 79 states generated, 38 distinct states, depth 4; Bash,
  Python, MPI, cancellation, task failure, master failure, and shutdown cleanup all passed.
- `ParslGlobusComputeConfig.cfg`: expected counterexample at depth 3 (38 states generated, 25
  distinct); interleaved submits can observe another task's temporary resource specification.
- `ParslGlobusComputeConfigFixed.cfg`: 37 states generated, 16 distinct states, depth 8;
  serialized submit sections preserve per-task resource specifications and default restoration.
- `ParslProviderKinds.cfg`: 424,001 states generated, 40,000 distinct states, depth 15;
  provider submit/status/cancel lifecycle, Slurm/Kubernetes status translation, missing-job
  handling, timeout-versus-failure distinction, cancellation outcomes, scale-in terminal
  handling, and resource admission all passed.
- `ParslAWSProviderStatus.cfg`: expected counterexample at depth 2 (4 states generated, 3
  distinct); an absent EC2 instance response produces no returned provider status.
- `ParslAWSProviderStatusFixed.cfg`: 11 states generated, 5 distinct states, depth 5; missing
  instance completion mapping and status translation passed.
- `ParslAWSProviderStatusPresent.cfg`: 11 states generated, 5 distinct states, depth 5; normal
  EC2 running-instance status translation passed.
- `ParslProviderStatusBatch.cfg`: 140,628 states generated, 17,672 distinct states, depth 6;
  bounded batch size, atomic status updates, scheduler-command failure preservation, missing-job
  completion mapping, and terminal-state stability all passed.
- `ParslKubernetesPolling.cfg`: expected counterexample at depth 1 (62 states generated, 22
  distinct); the actual exception branch fails `ErrorVisibility` because `RUNNING` is retained.
- `ParslKubernetesPollingFixed.cfg`: 85 states generated, 23 distinct states, depth 5;
  value-based error visibility, cancellation cleanup, phase translation, and terminal stability
  all passed.
- `ParslProviderExecutorBridge.cfg`: 3,511 states generated, 432 distinct states, depth 15;
  provider-to-executor admission, pre-manager and post-manager terminal failure, unknown-status
  tolerance, and terminal provider cleanup of manager capacity and in-flight work all passed.
- `ParslJoinCallbackRace.cfg`: 4,778 states generated, 956 distinct states, depth 11;
  early callback return, all-inner-done gating, join-lock serialization, ordered aggregation,
  duplicate callback tolerance, and delayed JoinError propagation all passed.
- `ParslJoinMemoData.cfg`: 1,697 states generated, 496 distinct states, depth 13;
  memo-hit completion without an attempt, staging/readiness gating for a DataFuture, ordered join
  aggregation, callback locking, and inner-failure propagation all passed.
- `ParslJoinMonitoring.cfg`: 7,545 states generated, 1,816 distinct states, depth 18;
  join status emission, memoized/staged inner readiness, radio reordering, database write failure
  and retry, version monotonicity, and terminal monitoring protection all passed.
- `ParslResourceAdmission.cfg`: 861 states generated, 288 distinct states, depth 9;
  WorkQueue-style resource field validation, complete resource-triplet enforcement, worker
  capacity accounting, queueing, dispatch, and release all passed with autolabel disabled.
- `ParslResourceAdmissionAutolabel.cfg`: 1,640 states generated, 489 distinct states, depth 9;
  partial resource specifications were admitted only under the autolabel-enabled contract, with
  the same capacity invariants passing.
- `ParslResourceScaling.cfg`: 987 states generated, 292 distinct states, depth 21;
  resource-driven scale-out, pending allocation success/failure rollback, capacity-guarded
  dispatch, retryable scaling pressure, and minimum-block scale-in safety all passed.
- `ParslPollerBadState.cfg`: 6,699 states generated, 936 distinct states, depth 12;
  status-poll ordering, `FAILED`/`MISSING` threshold handling, bad-state task failure, and
  suppression of later admission/scale-out all passed.
- `ParslSerializationWire.cfg`: 208 states generated, 73 distinct states, depth 14;
  three-buffer serialization, serializer headers, decimal length framing, ordered unpack/decode,
  dispatch gating, and corrupt-frame rejection all passed.
- `ParslSerializationWireFailure.cfg`: 21 states generated, 8 distinct states, depth 4;
  an unserializable callable was rejected before framing or dispatch.
- `ParslSerializationZMQBridge.cfg`: 104,657 states generated, 20,320 distinct states, depth 39;
  serializer-token correlation, route validation, drop/duplicate handling, decode-before-dispatch,
  worker-loss retry, and stale result suppression all passed.
- `ParslHtexResultQueue.cfg`: expected counterexample at depth 1 (10 states generated, 6 distinct);
  a malformed result causes the actual pop-before-validation path to leave a pending Future after
  the result thread exits.
- `ParslHtexResultQueueFixed.cfg`: 17 states generated, 7 distinct states, depth 3; malformed
  message failure, duplicate-result handling, valid/exception result mapping, and interchange
  failure cleanup all passed.
- `ParslHtexVersionMismatch.cfg`: expected counterexample at depth 2 (27 states generated, 12
  distinct); a task is accepted after mismatch but before the fatal result is consumed.
- `ParslHtexVersionMismatchFixed.cfg`: 30 states generated, 10 distinct states, depth 4; version
  mismatch rejection, fatal-result cleanup, and closed-interchange admission safety all passed.
- `ParslHtexDispatchPriority.cfg`: 78 states generated, 26 distinct states, depth 8; priority
  ordering, manager capacity, draining admission, completion release, and manager-failure
  cleanup all passed.
- `ParslMPISpec.cfg`: expected counterexample at depth 3 (21 states generated, 11 distinct);
  zero `num_nodes` is accepted and reaches the rank-derivation error path.
- `ParslMPISpecFixed.cfg`: 21 states generated, 10 distinct states, depth 6; empty-spec rejection,
  positive-node validation, rank derivation, and valid MPI launch admission all passed.
- `ParslHeartbeatProvider.cfg`: 588 states generated, 100 distinct states, depth 16;
  provider-unknown tolerance, heartbeat ticking/reset, manager expiry, reconnect, and terminal
  provider cleanup all passed.
- `ParslResultRace.cfg`: 143 states generated, 46 distinct states, depth 13;
  delayed failure/success callbacks, retry selection, late-success races, stale callback
  suppression, Future consistency, and retry bounds all passed.
- `ParslLocalExecutor.cfg`: 59 states generated, 19 distinct states, depth 17;
  a provider-free local executor completed through the common task/result protocol.
- `ParslFileContent.cfg`: 17,812 states generated, 3,247 distinct states, depth 54;
  dependency readiness, stage-out ordering, and symbolic output-content identity passed.
- `ParslInputCorruption.cfg`: 37,556 states generated, 7,024 distinct states, depth 66;
  a corrupted stage-in could not release the dependent task until repaired.
- `ParslFileCorruptionSmall.cfg`: 60,824 states generated, 10,424 distinct states, depth 64;
  corruption, repair/retransfer, and output-content safety passed for a minimal dependent DAG.
- `ParslRegistration.cfg`: 94 states generated, 29 distinct states, depth 18;
  unregistered workers could not receive work or heartbeat until manager registration.
- `ParslRegistrationFailure.cfg`: 7,067 states generated, 1,384 distinct states, depth 36;
  failed manager registration left the worker unavailable without violating bindings or Future consistency.
- `ParslRegistrationRecovery.cfg`: 7,067 states generated, 1,384 distinct states, depth 36;
  a failed manager could retry registration without becoming dispatchable before re-registration.
- `ParslIdleManagerTimeout.cfg`: 27,639 states generated, 5,359 distinct states, depth 38;
  an idle manager exceeding the heartbeat age was removed with provider/executor capacity cleared.
- `ParslMultiManagerTimeout.cfg`: 442,239 states generated, 59,892 distinct states, depth 40;
  one manager expiry preserved another active block before the final expiry took the executor down.
- `ParslExecutorDrain.cfg`: 3,696 states generated, 760 distinct states, depth 33;
  draining stopped new submissions while preserving safety for already submitted attempts.
- `ParslMisroute.cfg`: 370,669 states generated, 46,560 distinct states, depth 40;
  wrong-executor dispatches were rejected without worker binding or false Future completion.
- `ParslResultMisroute.cfg`: 371,765 states generated, 46,560 distinct states, depth 40;
  wrong-executor result envelopes were rejected before Future resolution.
- `ParslJoin.cfg`: 427,320 states generated, 66,459 distinct states, depth 61;
  `EventuallySettled` passed for an outer join task waiting on two inner Futures.
- `ParslJoinSafety.cfg`: 427,320 states generated, 66,459 distinct states, depth 61;
  join dependency and outer-Future safety invariants passed.
- `ParslJoinInvalid.cfg`: 1,114 states generated, 276 distinct states, depth 32;
  invalid join return values rejected the outer Future without a false success.
- `ParslMessaging.cfg`: 5,941,081 states generated, 679,392 distinct states, depth 49;
  task/result wire ordering, envelope validity, symbolic object-graph serialization, and
  stale-result invariants passed.
- `ParslMessageLoss.cfg`: 3,696 states generated, 760 distinct states, depth 33;
  task/result message loss, worker cleanup, retry bounds, and Future consistency passed.
- `ParslMessageDuplicate.cfg`: 100 states generated, 31 distinct states, depth 20;
  duplicate task/result envelopes were explicitly discarded without duplicate completion.

## Source-to-model mapping

| TLA+ action | Parsl concept | Current source location |
| --- | --- | --- |
| `BeginStaging` / `FinishStaging` | data readiness/staging | `parsl/data_provider/data_manager.py` |
| `CorruptStaging` / `RepairStaging` / `FileStagingSafety` | damaged input transfer and repair before dependency release | `DataManager.stage_in` and transfer error paths |
| `BeginStageOut` / `TransferOutputChunk` / `FinishStageOut` | staged output-file transfer after task completion | `DataFlowKernel` stage-out hooks and `DataManager.stage_out` |
| `FileChunkSafety` / `CorruptStageOut` / `RepairStageOut` | bounded transfer integrity and retransfer after corruption | `DataManager.stage_out` and provider/file-transfer error paths |
| `DependencyCheck` | wait for dependencies and unwrap Futures | `DataFlowKernel._launch_if_ready_async` |
| `MemoizationHit` | complete a Future from cache | `DataFlowKernel.launch_task` |
| `SubmitAttempt` | select an executor and call `submit` | `DataFlowKernel.launch_task` |
| `SerializationFailure` | callable/argument serialization failure before dispatch | `DataFlowKernel.launch_task` and executor serialization boundary |
| `ResultSerializationFailure` / `ResultSerializationSafety` | worker return-value serialization failure before transport | worker result encoding and executor/interchange result boundary |
| `ObjectGraphSerializable` / `ObjectGraphSafety` | callable, argument, closure, and nested-object serializability | Python callable/payload serialization boundary in `DataFlowKernel` and executor |
| `SerializeAttempt` / `SendAttempt` / `ReceiveAttempt` / `DecodeAttempt` | encode, transport, and decode a task message | `DataFlowKernel` submit path, interchange task transport, manager message handling |
| `DispatchAttempt` | interchange sends work to a manager | `Interchange.process_tasks_to_send` |
| `StartAttempt` | worker starts a decoded task | `process_worker_pool.py` |
| `SerializeResult` / `SendResult` / `ReceiveResult` / `DecodeResult` | encode, transport, and decode a worker result | `process_worker_pool.py`, `Interchange.process_manager_socket_message` |
| `taskWireState` / `resultWireState` and `MessageSafety` | bounded ZMQ-like queues and envelope/attempt ordering | interchange task/result queues and manager socket message handling |
| `AcknowledgeResult` | receiver-side result consume acknowledgement before decode | manager result receive/dispatch boundary |
| `DropTaskMessage` / `DropResultMessage` | transport loss before dispatch or Future resolution | interchange/socket failure boundary and retry handling |
| `DuplicateTaskMessage` / `DuplicateResultMessage` | duplicate delivery and receiver-side discard | interchange receive loop and result deduplication boundary |
| `MessageCorrelationSafety` | bind task/result envelopes to `(task, retryAttempt)` | interchange message identity and DFK current-attempt checks |
| `AttemptSuccess` | accept the current decoded result and resolve the Future | `DataFlowKernel.handle_exec_update` |
| `JoinObserve` / `JoinComplete` / `JoinFailure` | wait for inner Futures and propagate join result/failure | `DataFlowKernel.handle_exec_update`, `handle_join_update`, and `join_app` |
| `JOIN_INVALID` / `JoinSafety` / `JoinHandleSafety` / `JoinFailureSafety` | invalid return, handle lifetime, aggregate completion, and inner-failure propagation | `DataFlowKernel.handle_exec_update` and `handle_join_update` |
| `AttemptFailure` / `RetryTask` | retryable failure and resubmission | `DataFlowKernel.handle_exec_update` |
| `WorkerFailure` / `LateResult` | worker/manager loss and old-attempt results | `Interchange.expire_bad_managers`; stale-result behavior is explicit in the abstraction |
| `Tick` / `Heartbeat` / `AttemptTimeout` | logical time, manager heartbeat, and task timeout | `Interchange` heartbeat expiration and executor/worker timeout paths |
| `ExpireManager` / `Heartbeat` / `ExpirationAccounting` | strict heartbeat threshold and in-flight manager-loss cleanup | `Interchange.expire_bad_managers` and main polling loop |
| `PublishMonitor` | persist an asynchronous task status update | `DataFlowKernel._update_task_state`, `MonitoringHub`, and monitoring radios |
| `monitoringState.version` / `MonitoringDatabaseSafety` | ordered monitoring database writes | `MonitoringHub`/radio persistence boundary |
| `RegisterWorker` / `RegistrationSafety` | manager registration before dispatch | `Interchange` manager registration and worker availability |
| `RegistrationFailure` / `RetryRegistration` | manager startup failure and reconnect/re-registration | `Interchange` manager registration failure boundary |
| `IdleManagerTimeout` | idle manager heartbeat expiry and block cleanup | `Interchange` heartbeat expiration and executor/provider error handling |
| `ExecutorDrain` / `ExecutorRecover` | executor drain and reopening of task submission | executor scaling strategy and `HighThroughputExecutor.submit` |
| `MisrouteAttempt` | reject decoded work sent to the wrong manager/executor | `Interchange` dispatch routing and manager registration |
| `MisrouteResult` | reject result envelopes claiming the wrong executor | interchange result routing and DFK completion boundary |
| `SubmitFailure` | executor bad-state/submit rejection before worker dispatch | `BlockProviderExecutor.bad_state_is_set`, `HighThroughputExecutor.submit` |
| `ProviderFailure` | active provider block failure and executor/provider recovery | `JobStatusPoller`, `BlockProviderExecutor.handle_errors`, provider status/cancel paths |
| `ExecutorFailure` | executor/provider loss while an attempt is running | executor bad-state/error handling plus provider block failure |
| `RequestAllocation` / `AllocationSucceeds` / `AllocationFails` | provider submit/status and block lifecycle | `ExecutionProvider`, `BlockProviderExecutor.scale_out_facade` |
| `SubmitSuccess` / `SubmitEmptyCurrent` / `SubmitEmptyFixed` | PBS Pro `qsub` output parsing and job/resource registration | `PBSProProvider.submit` |
| `ForeignLineCrashes` / `ForeignLineIgnored` / `KnownLineUpdates` | Torque qstat foreign-job handling and status update | `TorqueProvider._status` |
| `CancelSuccess` / `CancelFailure` | Torque qdel outcome and resource-state convention | `TorqueProvider.cancel` |
| `MalformedLineCrashes` / `MalformedLineIgnored` / `ValidLineUpdates` | Condor status line length validation and update | `CondorProvider._status` |
| `MalformedLineCrashes` / `MalformedLineIgnored` / `ValidLineUpdates` | Grid Engine qstat line length validation and update | `GridEngineProvider._status` |
| `CancelAllocation` | scale-in of an idle block | `HighThroughputExecutor.scale_in`, `jobs/strategy.py` |
| `CancelRequestedAllocation` | cancel a pending provider block request | provider strategy cancellation boundary |
| `ScaleOut` / `StartIdleTimer` / `ScaleIn` in `ParslStrategy.tla` | slot-pressure scaling and idle-timeout policy | `parsl/jobs/strategy.py` |
| `EncodeHeader` / `EncodeBody` / `FinishEncode` | multipart task/result serialization before transport | DFK/interchange task path and worker result encoding |
| `Send` / `Deliver` / `DuplicateInbound` / `DropOutbound` | bounded ZMQ-like transport, reconnect loss, reordering, duplicate delivery | HTEX interchange and manager socket queues |
| `ReceiveValid` / `RejectInvalid` / `Ack` | receiver validation, correlation, and consume acknowledgement | interchange manager message handling and DFK result path |
| `StartEncode` / `EncodeObject` / `FinishEncode` | callable, globals, defaults, closure, and argument object serialization | DFK task serialization and executor submission boundary |
| `StartDecode` / `DecodeObject` / `FinishDecode` | reconstructing a callable/payload only after a complete encoded graph | worker-side task deserialization |
| `MutateObject` / `RepairObject` | object content becoming unencodable before submission | Python object/payload serialization failure path |
| `SendChunk` / `ReceiveChunk` / `RejectCorruptChunk` / `RepairChunk` | chunked content transfer, checksum validation, and retransmission | `DataManager.stage_in` / `stage_out` transfer paths |
| `PublishStageIn` / `RejectStaleStageIn` / `PublishStageOut` | readiness and atomic file visibility after complete transfer | DataManager staging completion and file publication boundary |
| `CompleteApp` / `StartStageOut` / `CompleteStageOut` / `RetryStageOut` | output `DataFuture` dependency on application or separate stage-out Future | `DataFlowKernel._add_output_deps` and `DataManager.stage_out` |
| `Tick` / `SendHeartbeat` / `DeliverHeartbeat` / `ExpireManager` | wall-clock and manager heartbeat expiry | HTEX interchange heartbeat and manager health handling |
| `StartAttempt` / `TimeoutAttempt` / `RetryAttempt` / `RetryLostAttempt` / `DeliverResult` | attempt deadline, manager-loss retry choice, and stale late result | DFK timeout/retry callbacks, HTEX manager-loss handling, and result completion path |
| `AdvanceStatus` / `EmitEvent` | logical task status event generation | DFK task-state update and monitoring radio send |
| `DeliverHead` / `ReorderRadio` / `WriteSuccess` / `WriteFailure` | asynchronous monitoring queue and database persistence | MonitoringHub/radio/database boundary |
| `BeginInsert` / `InsertRow` / `DuplicateRejected` / `DuplicateIgnored` | STATUS-table primary-key collision, generic exception loss, and idempotent repair | `parsl/monitoring/db_manager.py` `STATUS` schema and `DatabaseManager._insert` |
| `ReceiveFirstBeforeTry` / `InsertTaskAndTry` / `ReceiveFirstAfterTry` | deferred worker-task monitoring message replay and try-row ordering | `DatabaseManager.start` deferred-resource logic |
| `RequestBlock` / `AllocationSucceeds` / `AllocationFails` | provider request and block lifecycle | `ExecutionProvider` and `BlockProviderExecutor.scale_out_facade` |
| `StatusBatchSuccess` / `StatusBatchFailure` | bounded scheduler polling, atomic status update, and timeout/error preservation | `ClusterProvider.status`, `SlurmProvider._status`, and `execute_wait` |
| `BeginPoll` / `ReceiveEC2Response` / `Reset` | EC2 instance status translation and missing-instance handling | `AWSProvider.status` |
| `PollError` / `ErrorVisibility` | Kubernetes pod-read exception and UNKNOWN-state exposure, including the identity-check regression probe | `KubernetesProvider._status` |
| `RegisterManager` / `ReadyWorker` / `DispatchTask` | manager registration and worker-slot readiness | HTEX interchange/manager registration and worker pool |
| `SubmitTask` / `RejectSubmit` / `DrainExecutor` | executor submit admission and drain behavior | `HighThroughputExecutor.submit` and executor bad-state handling |
| `BeginShutdown` / `Complete` / `WorkQueueCollectorFails` / `HtexInterchangeLoss` | concrete executor shutdown and outstanding-task cleanup | `threads.py`, `workqueue/executor.py`, and `high_throughput/executor.py` |
| `Report` / `DecodeReport` / `CollectorFinallyFailsOutstanding` | WorkQueue result-file decoding and collector-exit Future cleanup | `WorkQueueExecutor._collect_work_queue_results` |
| `FluxSucceeds` / `PrepareResult` / `CompleteCallback` / `FluxCancels` | Flux job completion, result-file decoding, and wrapped-Future cancellation | `FluxExecutor._complete_future` and `FluxFutureWrapper.cancel` |
| `Submit` / `Report` / `Collect` / `ManagerFails` / `CollectorCleanup` | TaskVine task submission, result report mapping, and manager-loss Future cleanup | `TaskVineExecutor.submit`, `_collect_taskvine_results`, and TaskVine manager report generation |
| `TaskDone` / `TaskCanceled` / `TaskFailed` / `MasterFailed` / `Shutdown` | Radical Pilot callback mapping and pending-Future cleanup | `RadicalPilotExecutor.task_state_cb`, `_fail_all_tasks`, and `shutdown` |
| `BeginSubmit` / `UnderlyingSubmit` / `FinishSubmit` | Globus Compute temporary resource-specification override and restoration | `GlobusComputeExecutor.submit` |
| `DeliverMalformed` / `DeliverDuplicate` / `InterchangeFailure` | HTEX result-thread message validation, duplicate handling, and fatal interchange cleanup | `HighThroughputExecutor._result_queue_worker` |
| `RegisterMismatch` / `HandleFatalResult` | manager version rejection and pending-fatal admission race | `Interchange.process_manager_socket_message` and `HighThroughputExecutor.submit_payload` |
| `Dispatch` / `Complete` / `Drain` / `Recover` | HTEX pending-task priority, manager capacity, and draining admission | `Interchange.process_task_incoming`, `get_tasks`, and `process_tasks_to_send` |
| `Configure` / `Validate` / `DeriveRanks` / `Launch` | MPI resource-specification validation and derived rank counts | `MPIExecutor.validate_resource_spec` and `mpi_prefix_composer.validate_resource_spec` |
| `FailProvider` / `CancelAllocation` | provider failure and block-granular scale-in cleanup | `BlockProviderExecutor.handle_errors` and provider cancel/strategy paths |
| `ReturnSingle` / `ReturnList` / `ReturnEmptyList` / `ReturnInvalid` | `join_app` return-shape validation | `DataFlowKernel.handle_exec_update` join branch |
| `ObserveInner` / `FinalizeJoin` | inner Future callbacks, aggregate completion, and JoinError | `DataFlowKernel.handle_join_update` |
| `ObservePosition` / `DuplicateCallback` | ordered list-position callbacks and duplicate Future references | `DataFlowKernel.handle_join_update` list branch |
| `ReturnJoinable` / `ReturnMixedList` / `RegisterEmptyCompletion` | list element validation, immediate empty-list completion, and mixed-list rejection | `DataFlowKernel.handle_exec_update` join branch |
| `StartAttempt` / `FailAttempt` / `RetryAttempt` / `CompleteAttempt` in `ParslJoinRetry.tla` | inner Future retry lifecycle before join observation | DFK retry handling and inner Future callbacks |
| `StartNestedJoin` / `FinalizeNested` / `ObserveNestedResult` | nested join handle and result propagation | nested `join_app` callback composition |
| `BeginEncode` / `FinishEncodeSuccess` / `DecodeTaskSuccess` | serialized callable/payload gating task transport | DFK serialization boundary, interchange task queue, worker decode |
| `CorruptTaskEnvelope` / `DecodeTaskFailure` / `LoseAttempt` / `AcceptResult` | protocol corruption, worker loss, retry and stale result handling | HTEX message/result paths and DFK attempt correlation |
| `SubmitBlock` / `SubmitAccepted` / `SubmitRejected` | provider submit API and target rollback | `ExecutionProvider.submit` and block scaling facade |
| `BeginStatus` / `StatusPending` / `StatusRunning` / `StatusUnknown` | provider status polling and unknown-job failure | `ExecutionProvider.status` and `JobStatusPoller` |
| `BeginCancel` / `CancelAccepted` / `CancelFailed` | provider cancellation and rollback | `ExecutionProvider.cancel` and scale-in handling |
| `LocalExecutors` / `LocalExecutorSafety` | local executor path without provider provisioning or manager registration | `ThreadPoolExecutor` submission boundary |

## Representative traces

Normal execution:

```text
DependencyCheck(A), Enqueue(A), RequestAllocation(E1), AllocationSucceeds(E1,W1),
SubmitAttempt(A,E1), DispatchAttempt(A,0,W1), StartAttempt(A,0,W1),
AttemptSuccess(A,0,W1),
DependencyCheck(B), Enqueue(B), SubmitAttempt(B,E1), DispatchAttempt(B,0,W1),
StartAttempt(B,0,W1), AttemptSuccess(B,0,W1),
BeginStaging(C), FinishStaging(C), DependencyCheck(C), Enqueue(C), ...,
AttemptSuccess(C,0,W1)
```

Retry plus a late result:

```text
AttemptFailure(A,0,W1), RetryTask(A), SubmitAttempt(A,E1),
DispatchAttempt(A,1,W2), StartAttempt(A,1,W2),
LateResult(A,0),                 # (A,0) becomes stale; Future(A) is unchanged
AttemptSuccess(A,1,W2)           # Future(A) accepts only attempt 1
```

Two noteworthy source/model differences are intentional: Parsl's `States.running` is mainly
observed by monitoring while the DFK success path is `pending -> launched -> exec_done`; and
the real HTEX heartbeat, batching, and ZMQ message protocol are compressed into discrete
`DispatchAttempt` and `WorkerFailure` events. The model also prevents scale-in from silently
removing a provider block with an in-flight attempt.

## Concrete Parsl example

`parsl_demo.py` runs the same three-node dataflow shape with real Parsl. It demonstrates the
mapping, but it is not itself the TLC proof object: the TLA+ `result` token only means that
the result was accepted by the abstract DFK.

```bash
python3 -m pip install parsl
python3 parsl_demo.py
```
