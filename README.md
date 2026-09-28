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
active.

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
- `ParslScaleIn.cfg`: 52,674 states generated, 7,371 distinct states, depth 37;
  multi-block scale-out, partial scale-in, and failed secondary allocation preserved provider
  block/target consistency.
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
- `ParslRegistrationFailure.cfg`: 1,750 states generated, 429 distinct states, depth 32;
  failed manager registration left the worker unavailable without violating bindings or Future consistency.
- `ParslIdleManagerTimeout.cfg`: 10,808 states generated, 2,479 distinct states, depth 34;
  an idle manager exceeding the heartbeat age was removed with provider/executor capacity cleared.
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
| `PublishMonitor` | persist an asynchronous task status update | `DataFlowKernel._update_task_state`, `MonitoringHub`, and monitoring radios |
| `monitoringState.version` / `MonitoringDatabaseSafety` | ordered monitoring database writes | `MonitoringHub`/radio persistence boundary |
| `RegisterWorker` / `RegistrationSafety` | manager registration before dispatch | `Interchange` manager registration and worker availability |
| `RegistrationFailure` | manager startup/registration failure | `Interchange` manager registration failure boundary |
| `IdleManagerTimeout` | idle manager heartbeat expiry and block cleanup | `Interchange` heartbeat expiration and executor/provider error handling |
| `ExecutorDrain` / `ExecutorRecover` | executor drain and reopening of task submission | executor scaling strategy and `HighThroughputExecutor.submit` |
| `MisrouteAttempt` | reject decoded work sent to the wrong manager/executor | `Interchange` dispatch routing and manager registration |
| `MisrouteResult` | reject result envelopes claiming the wrong executor | interchange result routing and DFK completion boundary |
| `SubmitFailure` | executor bad-state/submit rejection before worker dispatch | `BlockProviderExecutor.bad_state_is_set`, `HighThroughputExecutor.submit` |
| `ProviderFailure` | active provider block failure and executor/provider recovery | `JobStatusPoller`, `BlockProviderExecutor.handle_errors`, provider status/cancel paths |
| `ExecutorFailure` | executor/provider loss while an attempt is running | executor bad-state/error handling plus provider block failure |
| `RequestAllocation` / `AllocationSucceeds` / `AllocationFails` | provider submit/status and block lifecycle | `ExecutionProvider`, `BlockProviderExecutor.scale_out_facade` |
| `CancelAllocation` | scale-in of an idle block | `HighThroughputExecutor.scale_in`, `jobs/strategy.py` |
| `CancelRequestedAllocation` | cancel a pending provider block request | provider strategy cancellation boundary |
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
