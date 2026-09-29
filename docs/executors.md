# Executor and HTEX models

These models cover executor lifecycle, task execution, HTEX submission and result queues, worker
registration, heartbeats, command deadlines, ThreadExecutor, WorkQueue, TaskVine, Flux, and
RadicalPilot result handling.

Files live in [`models/executors/`](../models/executors/). The full TLC command list is in
[the overview](overview.md).

`ParslThreadExecutorThreadCount.tla` models `ThreadPoolExecutor` admission of
`max_threads`. The current wrapper accepts zero at construction and fails only when `start()`
creates the underlying pool; the fixed branch rejects non-positive counts immediately. The
runtime probe exercises the real constructor/start boundary.

This delayed validation is recorded as BUG-127: an invalid executor configuration can survive
construction and fail only when the workflow starts.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslThreadExecutorThreadCountCurrent.cfg models/executors/ParslThreadExecutorThreadCount.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslThreadExecutorThreadCountFixed.cfg models/executors/ParslThreadExecutorThreadCount.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslThreadExecutorThreadCountValid.cfg models/executors/ParslThreadExecutorThreadCount.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_thread_executor_thread_count_runtime.py -v
```

`ParslThreadExecutorResourceSpec.tla` models the unsupported-resource boundary in
`ThreadPoolExecutor.submit`. A non-empty mapping is rejected with
`InvalidResourceSpecification`, but the current implementation calls `.keys()` before building
that exception. A truthy non-mapping value therefore raises `AttributeError`; the fixed branch
rejects it through the same controlled path. The runtime probe exercises both concrete inputs.

This type-validation escape is recorded as BUG-131.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslThreadExecutorResourceSpecCurrent.cfg models/executors/ParslThreadExecutorResourceSpec.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslThreadExecutorResourceSpecFixed.cfg models/executors/ParslThreadExecutorResourceSpec.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_thread_executor_resource_spec_runtime.py -v
```

`ParslHtexManagerEligibility.tla` separates manager ordering from dispatch admission. The
selector may return inactive or draining managers as candidates, but the interchange must check
`active` and `draining` again before sending a task. The bounded model skips `m0` (inactive) and
`m1` (draining) and sends only to `m2`; the runtime probe drives the real
`Interchange.process_tasks_to_send` method with a deterministic selector and recording socket.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexManagerEligibility.cfg models/executors/ParslHtexManagerEligibility.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_htex_manager_eligibility_runtime.py -v
```

`ParslPoolExecutorMap.tla` models the concrete `parsl.concurrent.ParslPoolExecutor.map` wrapper.
The pool submits all inputs eagerly, consumes results in input order, and treats `timeout` as a
deadline for the result iterator. A timeout does not cancel already-submitted Parsl Futures, and
those Futures may complete after the iterator has stopped. The runtime probe uses real
`concurrent.futures.Future` objects with the Parsl wrapper and also checks that
`shutdown(cancel_futures=True)` is advisory, as documented by Parsl.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslPoolExecutorMap.cfg models/executors/ParslPoolExecutorMap.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_pool_executor_map_runtime.py -v
```

`ParslHtexCoresPerWorker.tla` models HTEX worker-capacity calculation when a provider advertises
`cores_per_node`. The current constructor allows `cores_per_worker=0` to reach the division used
to compute CPU slots and raises `ZeroDivisionError`; the fixed branch rejects the non-positive
configuration before capacity calculation. The runtime probe uses a real `LocalProvider` with a
CPU hint and the real `HighThroughputExecutor` constructor.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexCoresPerWorkerCurrent.cfg models/executors/ParslHtexCoresPerWorker.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexCoresPerWorkerFixed.cfg models/executors/ParslHtexCoresPerWorker.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexCoresPerWorkerValid.cfg models/executors/ParslHtexCoresPerWorker.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_htex_cores_per_worker_runtime.py -v
```

This worker-capacity admission boundary is recorded as BUG-113: zero `cores_per_worker` reaches
the capacity division and raises `ZeroDivisionError` during executor construction.

`ParslHtexAddressProbeTimeout.tla` models propagation of an explicit
`address_probe_timeout` into the worker launch command. The current
`initialize_scaling()` uses a truthiness check, so a configured zero is omitted
and the worker-side default is used instead; the fixed branch preserves every
non-`None` value. The runtime probe composes the real HTEX command.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexAddressProbeTimeoutCurrent.cfg models/executors/ParslHtexAddressProbeTimeout.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexAddressProbeTimeoutFixed.cfg models/executors/ParslHtexAddressProbeTimeout.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexAddressProbeTimeoutValid.cfg models/executors/ParslHtexAddressProbeTimeout.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_htex_address_probe_timeout_runtime.py -v
```

This timeout-propagation boundary is recorded as BUG-114: an explicit zero is omitted from the
worker command by a truthiness check and replaced by the worker default.

`ParslProbeAddresses.tla` abstracts the HTEX `probe_addresses` helper. It distinguishes an empty
candidate set (`ValueError`), a successful probe reply selecting an address, and timeout without a
reply (`ConnectionError`). The runtime probe uses the real pyzmq context for the empty and
unresponsive-address paths.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslProbeAddresses.cfg models/executors/ParslProbeAddresses.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslProbeAddressesEmpty.cfg models/executors/ParslProbeAddresses.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslProbeAddressesSuccess.cfg models/executors/ParslProbeAddresses.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_probe_addresses_runtime.py -v
```

`ParslHtexTaskPriorityType.tla` covers a decoded task whose `resource_spec.priority` is not
numeric. The current queue key uses unary negation and raises `TypeError`; the fixed branch
rejects the task before insertion. The runtime probe exercises this object-type boundary with a
fake task socket.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexTaskPriorityTypeCurrent.cfg models/executors/ParslHtexTaskPriorityType.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexTaskPriorityTypeFixed.cfg models/executors/ParslHtexTaskPriorityType.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_htex_task_priority_type_runtime.py -v
```

`ParslHtexTaskResourceSpecType.tla` refines task-object validation beyond missing fields. A
decoded task whose `context.resource_spec` is a list (or another non-mapping object) currently
raises `AttributeError` when the interchange calls `.get`. The fixed branch rejects the object
before queue insertion. The runtime probe exercises this type boundary with a fake socket.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexTaskResourceSpecTypeCurrent.cfg models/executors/ParslHtexTaskResourceSpecType.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexTaskResourceSpecTypeFixed.cfg models/executors/ParslHtexTaskResourceSpecType.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_htex_task_resource_spec_type_runtime.py -v
```

`ParslHtexTaskMessageMalformed.tla` covers malformed Python objects arriving on the HTEX task
socket. The current interchange path indexes `task_id` and `context` without a validation guard,
so a missing field raises out of the polling loop. The fixed branch discards the malformed task
and keeps the interchange alive. The runtime probe invokes the concrete task-message handler with
a fake ZMQ socket.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexTaskMessageMalformedCurrent.cfg models/executors/ParslHtexTaskMessageMalformed.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexTaskMessageMalformedFixed.cfg models/executors/ParslHtexTaskMessageMalformed.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_htex_task_message_malformed_runtime.py -v
```

`ParslResultsIncoming.tla` models the concrete `ResultsIncoming` DEALER wrapper in
`high_throughput/zmq_pipes.py`: a readable socket yields one multipart message, a poll timeout
returns `None`, and `close()` shuts down both the socket and its ZMQ context. The two configurations
cover readable and timeout paths, while `tests/test_results_incoming_runtime.py` drives the real
wrapper with a fake socket.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslResultsIncoming.cfg models/executors/ParslResultsIncoming.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslResultsIncomingTimeout.cfg models/executors/ParslResultsIncoming.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_results_incoming_runtime.py -v
```

`ParslTasksOutgoing.tla` covers the matching task sender: `put()` sends one Python object over the
DEALER socket without a reply handshake, and `close()` terminates the socket/context so the sender
is no longer open. `tests/test_tasks_outgoing_runtime.py` checks the real wrapper boundary with a
fake socket.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslTasksOutgoing.cfg models/executors/ParslTasksOutgoing.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_tasks_outgoing_runtime.py -v
```

`ParslFluxCancelUnderlyingState.tla` isolates a second Flux cancellation boundary. If the
underlying Flux future is already cancelled, the current `FluxFutureWrapper.cancel()` returns
`True` without transitioning the Parsl wrapper, leaving the user-visible Future pending. The
fixed branch propagates the terminal cancellation; the runtime probe drives the real wrapper with
an already-cancelled fake future.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslFluxCancelUnderlyingStateCurrent.cfg models/executors/ParslFluxCancelUnderlyingState.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslFluxCancelUnderlyingStateFixed.cfg models/executors/ParslFluxCancelUnderlyingState.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_flux_cancel_underlying_state_runtime.py -v
```

`ParslCommandClientSendTimeout.tla` adds the pre-send timeout branch of the HTEX REQ/REP command
client. A `POLLOUT` timeout occurs before any request is put on the socket, so it leaves
`client.ok` true and a later command can safely retry; this contrasts with a post-send reply
timeout, which poisons the client. The runtime probe checks both the empty first send and the
successful second command.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslCommandClientSendTimeout.cfg models/executors/ParslCommandClientSendTimeout.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_command_send_timeout_runtime.py -v
```

`ParslCommandClientLockTimeout.tla` models the timeout boundary around the client's Python
mutex. The current `CommandClient.run` starts its deadline before `with self._lock`, so a caller
blocked behind another command can acquire the lock after its deadline and still send. The fixed
branch makes lock acquisition deadline-aware. The runtime probe holds the real lock, invokes
`run(timeout_s=...)` in another thread, and verifies the late send.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslCommandClientLockTimeoutCurrent.cfg models/executors/ParslCommandClientLockTimeout.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslCommandClientLockTimeoutFixed.cfg models/executors/ParslCommandClientLockTimeout.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_command_lock_timeout_runtime.py -v
```

This lock/deadline boundary is recorded as BUG-110: waiting for the Python lock can consume the
entire command deadline, yet the current path still sends the request after acquisition.

`ParslCommandDeadline.tla` covers the expired-deadline arithmetic inside each REQ/REP poll. The
current path forwards a negative remaining duration to `zmq.Socket.poll`; the fixed branch clamps
the value to zero before deciding that the command has timed out. The existing runtime probe
records the negative timeout passed by the real `CommandClient`.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslCommandDeadlineCurrent.cfg models/executors/ParslCommandDeadline.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslCommandDeadlineFixed.cfg models/executors/ParslCommandDeadline.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslCommandDeadlineNormal.cfg models/executors/ParslCommandDeadline.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_command_deadline_runtime.py -v
```

`ParslCommandClientMaxRetries.tla` records a source-level audit finding: `CommandClient.run`
accepts `max_retries`, but the current implementation does not read it. A transient
`send_pyobj` exception therefore escapes after exactly one send for both `max_retries=0` and
`max_retries=2`. The current TLC configuration violates `RetryBudgetHonored`; the fixed
configuration models one retry and passes. This is an API/implementation mismatch, not an
assumption that the paper requires a particular retry policy.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslCommandClientMaxRetriesCurrent.cfg models/executors/ParslCommandClientMaxRetries.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslCommandClientMaxRetriesFixed.cfg models/executors/ParslCommandClientMaxRetries.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_command_max_retries_runtime.py -v
```

This API/implementation mismatch is recorded as BUG-109: `max_retries` is accepted but ignored
when `send_pyobj` raises.

`ParslHtexCancelledResult.tla` covers a result arriving after a user cancelled its Future. The
current HTEX result thread calls `set_result` unconditionally; `InvalidStateError` terminates the
thread after removing the cancelled task, so later results in the same batch remain pending. The
fixed branch discards the cancelled result and continues. `tests/test_htex_cancelled_result_runtime.py`
reproduces the current failure with two messages in one batch.

`ParslHtexDuplicateResult.tla` is the focused duplicate-delivery abstraction for an
already-completed task result. `ParslHtexResultQueue.tla` also covers this path alongside
malformed and terminal results.
The current worker has removed the task from `_tasks`, so a second frame raises `KeyError` and
terminates the result thread. The candidate fixed branch treats the frame as stale and keeps the
worker alive for unrelated tasks. The duplicate-result case is exercised by
`test_htex_result_queue_runtime.py`.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexCancelledResultCurrent.cfg models/executors/ParslHtexCancelledResult.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexCancelledResultFixed.cfg models/executors/ParslHtexCancelledResult.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_htex_cancelled_result_runtime.py -v
```

`ParslHtexUnknownTaskResult.tla` covers a stale result whose `task_id` is no longer present in
the executor task map. The current result worker calls `pop` unconditionally, so a `KeyError`
terminates the result loop and strands later valid results in the same batch. The fixed branch
discards the unknown result and continues. The runtime probe sends one stale and one live result
through the concrete HTEX result worker.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexUnknownTaskResultCurrent.cfg models/executors/ParslHtexUnknownTaskResult.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexUnknownTaskResultFixed.cfg models/executors/ParslHtexUnknownTaskResult.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_htex_unknown_task_result_runtime.py -v
```

`ParslHtexAmbiguousResult.tla` models a malformed HTEX result carrying both `result` and
`exception` fields. The current worker checks `result` first and silently resolves the Future,
discarding the exception payload; the fixed branch rejects the ambiguous frame while keeping the
worker alive. The runtime probe sends the conflicting message through the concrete result worker.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexAmbiguousResultCurrent.cfg models/executors/ParslHtexAmbiguousResult.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexAmbiguousResultFixed.cfg models/executors/ParslHtexAmbiguousResult.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_htex_ambiguous_result_runtime.py -v

The runtime probe also records BUG-101: a result frame containing both `result` and
`exception` is currently accepted with the result winning, silently dropping the exception
payload.  The model's fixed branch rejects this ambiguous frame.
```

`ParslMPINonDivisibleRanks.tla` audits `MPIExecutor` resource derivation. With `num_nodes=2`
and `num_ranks=5`, the current helper derives `ranks_per_node="2.5"` and emits that value in
the `mpiexec -ppn` option. The current TLC model violates `IntegralRanksSafety`; the fixed branch
rejects the allocation before launch. The runtime probe confirms the exact generated command.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslMPINonDivisibleRanksCurrent.cfg models/executors/ParslMPINonDivisibleRanks.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslMPINonDivisibleRanksFixed.cfg models/executors/ParslMPINonDivisibleRanks.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_mpi_nondivisible_runtime.py -v
```

`ParslMPINoResourceResult.tla` models the MPI scheduler result path for a task that did not
request MPI nodes. Such tasks are valid but are not inserted into `_map_tasks_to_nodes`; the
current `get_result` assertion nevertheless requires a mapping and aborts the scheduler. The
fixed branch returns the result without reclaiming nodes. The runtime probe invokes the real
method with an unmapped result payload.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslMPINoResourceResultCurrent.cfg models/executors/ParslMPINoResourceResult.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslMPINoResourceResultFixed.cfg models/executors/ParslMPINoResourceResult.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_mpi_no_resource_result_runtime.py -v
```

`ParslMPIBacklogRetry.tla` models the MPI backlog scheduler when its head task needs more nodes
than are currently free. The current `_schedule_backlog_tasks` requeues that task and immediately
recurses, so an unchanged resource count eventually raises `RecursionError`. The fixed branch
leaves the task queued until a result returns nodes. The runtime probe drives the real scheduler
with one free node and a two-node request.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslMPIBacklogRetryCurrent.cfg models/executors/ParslMPIBacklogRetry.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslMPIBacklogRetryFixed.cfg models/executors/ParslMPIBacklogRetry.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_mpi_backlog_retry_runtime.py -v
```

`ParslBashTimeoutCleanup.tla` covers the Bash app walltime boundary. The current
`remote_side_bash_executor` raises `AppTimeout` after `Popen.wait(timeout=...)` expires but does
not kill the shell/process group, leaving the timed-out command alive. The fixed branch performs
cleanup before reporting the timeout. The runtime probe uses a fake `Popen` to verify that the
current path makes no kill call.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslBashTimeoutCleanupCurrent.cfg models/executors/ParslBashTimeoutCleanup.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslBashTimeoutCleanupFixed.cfg models/executors/ParslBashTimeoutCleanup.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_bash_timeout_cleanup_runtime.py -v
```

`ParslHtexForceScaleIn.tla` models the concrete `HighThroughputExecutor.scale_in` policy.
With the default `max_idletime=None`, the current implementation deliberately selects the
longest-idle block even when its manager still reports active tasks, calls `_hold_block`, and
cancels the provider job. The current TLC branch therefore violates `BusyScaleInSafety`; the
fixed branch represents an idle-only policy. The runtime probe uses a busy fake manager and
checks the real block/provider cancellation calls. This captures the source docstring's
explicitly rude forced scale-in behavior (issue #530).

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexForceScaleInCurrent.cfg models/executors/ParslHtexForceScaleIn.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexForceScaleInFixed.cfg models/executors/ParslHtexForceScaleIn.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_htex_force_scale_in_runtime.py -v
```

`ParslWorkQueueCancelledResult.tla` models a Work Queue collector result racing with cancellation.
The current collector removes the cancelled Future and calls `set_result`, so `InvalidStateError`
exits the collector; its `finally` block then marks an unrelated pending Future as
`WorkQueueFailure`. The fixed branch discards the stale result and continues collecting. The
runtime probe drives two fake reports through the real collector method.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslWorkQueueCancelledResultCurrent.cfg models/executors/ParslWorkQueueCancelledResult.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslWorkQueueCancelledResultFixed.cfg models/executors/ParslWorkQueueCancelledResult.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_workqueue_cancelled_result_runtime.py -v
```

`ParslWorkQueueResourceCategory.tla` models the Work Queue resource specification schema. The
current `submit` method has a `category` handling branch, but omits `category` from
`acceptable_fields`, so a valid category is rejected before task mapping. The fixed branch accepts
the key. The runtime probe drives the real `WorkQueueExecutor.submit` validation path.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslWorkQueueResourceCategoryCurrent.cfg models/executors/ParslWorkQueueResourceCategory.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslWorkQueueResourceCategoryFixed.cfg models/executors/ParslWorkQueueResourceCategory.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_workqueue_submit_runtime.py -v
```

`ParslFluxProviderStatusEmpty.tla` audits the provider polling boundary used before a Flux
instance becomes reachable. `_check_provider_job` currently indexes the first element of
`provider.status([job_id])` without checking that the provider returned a status record. An
empty response therefore raises `IndexError` in the submission thread; the fixed branch treats
the empty response as an explicit provider failure. The runtime probe drives the current helper
with a fake provider returning an empty list.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslFluxProviderStatusEmptyCurrent.cfg models/executors/ParslFluxProviderStatusEmpty.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslFluxProviderStatusEmptyFixed.cfg models/executors/ParslFluxProviderStatusEmpty.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_flux_provider_status_empty_runtime.py -v
```

`ParslTaskVineCancelledResult.tla` covers the corresponding TaskVine collector race. A cancelled
Future causes the current collector's unconditional `set_result` to raise after the report is
removed; cleanup then marks another outstanding Future with `TaskVineManagerFailure`. The fixed
branch ignores the stale report and continues. `tests/test_taskvine_cancelled_result_runtime.py`
drives two real result-file reports through the collector boundary.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslTaskVineCancelledResultCurrent.cfg models/executors/ParslTaskVineCancelledResult.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslTaskVineCancelledResultFixed.cfg models/executors/ParslTaskVineCancelledResult.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_taskvine_cancelled_result_runtime.py -v
```

`ParslTaskVineFactory.tla` models the optional TaskVine factory process. The factory is created,
configured with worker/factory timeouts and capacity limits, entered as a context manager, and
kept alive until the executor stop event is set. The runtime probe patches the optional TaskVine
SDK with a fake factory and checks the real `_taskvine_factory` configuration boundary.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslTaskVineFactory.cfg models/executors/ParslTaskVineFactory.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_taskvine_factory_runtime.py -v
```

`ParslTaskVineSubmit.tla` models TaskVine submission ordering. The current executor inserts the
Future into its task map before serializing the callable and before checking submit-process
liveness, so either failure leaves an orphaned Future; the fixed branch rolls that map entry back.
The runtime probe drives both failures through the real `TaskVineExecutor.submit` with fake queues,
process state, and serialization.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslTaskVineSubmitCurrent.cfg models/executors/ParslTaskVineSubmit.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslTaskVineSubmitFixed.cfg models/executors/ParslTaskVineSubmit.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_taskvine_submit_runtime.py -v
```

The TaskVine submit model also checks serialization failure independently from process failure.
`ParslTaskVineSubmitSerializationFailure.cfg` reproduces the orphaned mapping, while the fixed
configuration rolls it back.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslTaskVineSubmitSerializationFailure.cfg models/executors/ParslTaskVineSubmit.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslTaskVineSubmitSerializationFailureFixed.cfg models/executors/ParslTaskVineSubmit.tla
```

`ParslWorkQueueSubmit.tla` applies the same submit-lifecycle boundary to Work Queue. The current
executor registers a Future before callable serialization and before checking the submit process;
both failures can leave an orphaned pending mapping. The fixed branch rolls back that mapping.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslWorkQueueSubmitFailure.cfg models/executors/ParslWorkQueueSubmit.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslWorkQueueSubmitFixed.cfg models/executors/ParslWorkQueueSubmit.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslWorkQueueSubmitSerializationFailure.cfg models/executors/ParslWorkQueueSubmit.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslWorkQueueSubmitSerializationFailureFixed.cfg models/executors/ParslWorkQueueSubmit.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_workqueue_submit_runtime.py -v
```

`ParslScaleOutFailureMonitoring.tla` models partial provisioning during
`BlockProviderExecutor.scale_out_facade`: one block succeeds and a later provider submission
fails. The current implementation stores the failed block in `_status` and notifies the
monitoring radio, but the BLOCK_INFO payload contains only the successful pending block because
only that branch adds to `monitoring_status_changes`. The fixed branch includes the failed block
in the payload. The runtime probe uses a real `BlockProviderExecutor` subclass and a provider
that succeeds once before raising.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslScaleOutFailureMonitoringCurrent.cfg models/executors/ParslScaleOutFailureMonitoring.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslScaleOutFailureMonitoringFixed.cfg models/executors/ParslScaleOutFailureMonitoring.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_scale_out_failure_monitoring_runtime.py -v
```

`ParslProvisioningAdmissionMonitoring.tla` connects block provisioning to executor admission and
monitoring. A queued task is admitted only with an active provider block; failed scale-out or
block loss moves the task toward retry. The current branch drops the failed-block monitoring
update and TLC finds `FailureVisibility` at depth 3; the fixed branch reports the failure and
checks 10 distinct states. This is a compact bridge between `BlockProviderExecutor` status,
strategy capacity, and DFK monitoring.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslProvisioningAdmissionMonitoringCurrent.cfg models/executors/ParslProvisioningAdmissionMonitoring.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslProvisioningAdmissionMonitoringFixed.cfg models/executors/ParslProvisioningAdmissionMonitoring.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_scale_out_failure_monitoring_runtime.py tests/test_htex_force_scale_in_runtime.py tests/test_provider_poll_clock_runtime.py -v
```

`ParslScaleInRetryMonitoring.tla` connects busy-worker scale-in to retry and monitoring. The
current branch cancels a block with a running task, then accepts the old worker's late completion
as success; TLC finds `LostTaskSafety` at depth 4. The fixed branch protects busy capacity and
classifies the late result as stale (5 distinct states checked).

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslScaleInRetryMonitoringCurrent.cfg models/executors/ParslScaleInRetryMonitoring.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslScaleInRetryMonitoringFixed.cfg models/executors/ParslScaleInRetryMonitoring.tla
```

`ParslHtexResultMessageMalformed.tla` covers a corrupt pickle frame inside an otherwise valid
HTEX manager result batch. `process_manager_socket_message` parses the batch metadata but the
current loop calls `pickle.loads` on each payload without a per-frame guard, so a malformed frame
escapes the interchange processing path. The fixed branch discards the bad frame and keeps the
manager protocol alive. The runtime probe sends the malformed frame through the real method.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexResultMessageMalformedCurrent.cfg models/executors/ParslHtexResultMessageMalformed.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexResultMessageMalformedFixed.cfg models/executors/ParslHtexResultMessageMalformed.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_htex_result_message_malformed_runtime.py -v
```

`ParslHtexResultBatchContinuation.tla` makes the consequence explicit: a malformed frame is
followed by a valid result for another task. The current branch aborts before forwarding the
valid frame; the candidate fixed branch discards only the malformed frame and forwards the valid
one. The runtime probe uses one real `recv_multipart` batch with both payloads and checks that the
current loop leaves the valid task outstanding after the decode exception.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexResultBatchContinuationCurrent.cfg models/executors/ParslHtexResultBatchContinuation.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexResultBatchContinuationFixed.cfg models/executors/ParslHtexResultBatchContinuation.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_htex_result_batch_continuation_runtime.py -v
```

`ParslHtexExecutorResultFrameContinuation.tla` covers the corresponding executor-side boundary.
The result queue can contain a corrupt outer pickle frame followed by a valid frame for another
task. The current `_result_queue_worker` lets `pickle.loads` escape and leaves both Futures
pending; the candidate fixed path discards the corrupt frame and continues. The runtime probe
uses real Parsl serialization for the valid result.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexExecutorResultFrameContinuationCurrent.cfg models/executors/ParslHtexExecutorResultFrameContinuation.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexExecutorResultFrameContinuationFixed.cfg models/executors/ParslHtexExecutorResultFrameContinuation.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_htex_executor_result_frame_continuation_runtime.py -v
```

`ParslHtexWorkerTaskFrameContinuation.tla` covers the manager-side task socket. A corrupt outer
pickle frame is followed by a valid task batch; the current `Manager.interchange_communicator`
lets the decode exception escape and stops receiving, while the candidate fixed path discards the
bad frame and accepts the later batch. The runtime probe drives the real communicator with a
controlled ZMQ-socket double.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexWorkerTaskFrameContinuationCurrent.cfg models/executors/ParslHtexWorkerTaskFrameContinuation.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexWorkerTaskFrameContinuationFixed.cfg models/executors/ParslHtexWorkerTaskFrameContinuation.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_htex_worker_task_frame_continuation_runtime.py -v
```

`ParslHtexWorkerTaskBatchShape.tla` refines task admission after outer pickle decoding. A
pickleable dictionary is not a valid task list, but the current communicator proceeds with list
operations and task-field indexing, allowing a `TypeError`/`KeyError` to stop the loop. The
candidate fixed branch validates the batch shape and continues to a later valid list. The runtime
probe uses real pickle payloads and the concrete communicator method.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexWorkerTaskBatchShapeCurrent.cfg models/executors/ParslHtexWorkerTaskBatchShape.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexWorkerTaskBatchShapeFixed.cfg models/executors/ParslHtexWorkerTaskBatchShape.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_htex_worker_task_batch_shape_runtime.py -v
```

`ParslRadicalPilotFailurePayload.tla` refines the RADICAL-Pilot callback mapping. If a failed
Python task has no serialized exception payload, the current callback passes a string to
`Future.set_exception`, which produces a callback-level `TypeError`; the fixed configuration wraps
the missing payload in a real `RuntimeError`. `test_radical_results_runtime.py` contains the
corresponding source-level probe.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslRadicalPilotFailurePayloadCurrent.cfg models/executors/ParslRadicalPilotFailurePayload.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslRadicalPilotFailurePayloadFixed.cfg models/executors/ParslRadicalPilotFailurePayload.tla
```

`ParslRadicalPilotLateCallback.tla` models a RADICAL-Pilot `CANCELED` callback racing with a
late `DONE` callback for the same task. The current `task_state_cb` calls `set_result` even
after the Parsl Future has been cancelled, raising `InvalidStateError`; the fixed branch drops
callbacks after terminal state. The runtime probe invokes the real callback twice with a fake RP
task and observes the exception.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslRadicalPilotLateCallbackCurrent.cfg models/executors/ParslRadicalPilotLateCallback.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslRadicalPilotLateCallbackFixed.cfg models/executors/ParslRadicalPilotLateCallback.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_radical_late_callback_runtime.py -v
```

`ParslRadicalPilotBulkShutdown.tla` models Radical Pilot bulk mode during shutdown. The current
shutdown sets `_terminate` before joining the bulk collector; the collector exits without flushing
its queue, leaving a queued task and its Future unresolved. The fixed branch flushes queued tasks
before exit. The runtime probe invokes the real `_bulk_collector` with a stop event and one queued
task.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslRadicalPilotBulkShutdownCurrent.cfg models/executors/ParslRadicalPilotBulkShutdown.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslRadicalPilotBulkShutdownFixed.cfg models/executors/ParslRadicalPilotBulkShutdown.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_radical_bulk_shutdown_runtime.py -v
```

`ParslWorkQueueShutdown.tla` models the Work Queue collector's finalization contract. Shutdown
sets the stop flag and waits for the collector; its `finally` block fails every accepted Future
that has no result before the executor reaches `stopped`. The runtime probe invokes the real
collector method with an already-set stop flag and an outstanding Future.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslWorkQueueShutdown.cfg models/executors/ParslWorkQueueShutdown.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_workqueue_shutdown_runtime.py -v
```

`ParslTaskVineShutdown.tla` models the corresponding TaskVine collector path. Its stop event and
task map are separate from Work Queue's, and outstanding Futures receive `TaskVineManagerFailure`
before the collector exits. `tests/test_taskvine_shutdown_runtime.py` invokes the real collector
with a stopped flag and an outstanding Future.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslTaskVineShutdown.cfg models/executors/ParslTaskVineShutdown.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_taskvine_shutdown_runtime.py -v
```

`ParslFluxSubmissionFailure.tla` covers the Flux submission-thread exception path. `_error_out_jobs`
continues draining queued jobs after the stop event is set and fails each queued Future. The
runtime probe calls that real helper with a one-job queue.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslFluxSubmissionFailure.cfg models/executors/ParslFluxSubmissionFailure.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_flux_submission_failure_runtime.py -v
```

`ParslFluxCancelSubmitRace.tla` models a Flux-specific cancellation race. If the wrapper is
cancelled while `_flux_future` is still unbound, a later successful underlying callback can call
`set_result` on the already-cancelled wrapper. The current configuration reaches the callback
error; the fixed branch propagates the cancellation into the bind step and suppresses the late
callback. `tests/test_flux_cancel_submit_race_runtime.py` reproduces the interleaving directly.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslFluxCancelSubmitRaceCurrent.cfg models/executors/ParslFluxCancelSubmitRace.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslFluxCancelSubmitRaceFixed.cfg models/executors/ParslFluxCancelSubmitRace.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_flux_cancel_submit_race_runtime.py -v
```

`ParslFluxErrorCleanupCancellation.tla` covers the Flux submit-thread failure cleanup path.
`_error_out_jobs` currently calls `set_exception` on queued Futures without checking whether
the user already canceled them. A canceled first Future can therefore raise `InvalidStateError`
and strand later queued Futures; the fixed branch skips terminal Futures and continues draining.
The runtime probe invokes the real cleanup helper with two queued Futures.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslFluxErrorCleanupCancellationCurrent.cfg models/executors/ParslFluxErrorCleanupCancellation.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslFluxErrorCleanupCancellationFixed.cfg models/executors/ParslFluxErrorCleanupCancellation.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_flux_error_cleanup_cancellation_runtime.py -v
```

`ParslGlobusComputeResult.tla` models the result boundary of `GlobusComputeExecutor.submit`.
The wrapper returns the underlying Globus Compute SDK `Future` directly, so success, remote
exception, and cancellation are visible to Parsl without an additional result wrapper. The
runtime probe uses a fake SDK executor and checks Future identity and all three terminal outcomes.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslGlobusComputeResult.cfg models/executors/ParslGlobusComputeResult.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_globus_compute_result_runtime.py -v
```

`ParslGlobusComputeSubmitRace.tla` refines the other side of that wrapper. The current
`submit` implementation temporarily mutates one shared SDK executor before calling its
`submit`; overlapping calls can therefore make task A observe task B's resource specification
or the restored default. The current TLC branch finds that interleaving, while the fixed branch
serializes the override/submit/restore critical section with a lock. The runtime probe uses two
threads and a deterministic fake SDK executor to reproduce the wrong configuration observation.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslGlobusComputeSubmitRaceCurrent.cfg models/executors/ParslGlobusComputeSubmitRace.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslGlobusComputeSubmitRaceFixed.cfg models/executors/ParslGlobusComputeSubmitRace.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_globus_compute_submit_race_runtime.py -v
```

`ParslExecutorProviderLifecycle.tla` connects provider allocation, manager registration, free
worker slots, queued/running tasks, executor drain, and provider terminal cleanup. The current
configuration finds a `MinBlockSafety` counterexample when scale-in leaves an active provider
below `MIN_BLOCKS`; the fixed configuration enforces the floor and checks 161 states.

`ParslHeartbeatLateAck.tla` isolates the in-flight heartbeat race: a manager can expire before an
old heartbeat reaches the interchange. The current branch accepts that stale acknowledgement and
resurrects the manager, violating `ExpiryTerminal`; the fixed branch ignores it as stale. This
matches the manager-record lookup guard in HTEX `interchange.py` before processing messages.

`ParslHtexSubmitLifecycle.tla` refines HTEX submission ordering. Serialization failure
terminates before a task/Future is allocated, while an outgoing-queue failure happens after
allocation. The current queue-failure configuration leaves an orphaned pending Future and
violates `QueueFailureSafety`; the fixed configuration removes the task mapping and fails the
Future. The serialization-failure configuration passes with no Future allocation.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexSubmitLifecycleQueueFailure.cfg models/executors/ParslHtexSubmitLifecycle.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexSubmitLifecycleQueueFailureFixed.cfg models/executors/ParslHtexSubmitLifecycle.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexSubmitLifecycleSerializationFailure.cfg models/executors/ParslHtexSubmitLifecycle.tla
```

Run this focused check with:

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHeartbeatLateAck.cfg models/executors/ParslHeartbeatLateAck.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHeartbeatLateAckFixed.cfg models/executors/ParslHeartbeatLateAck.tla
```

`ParslBlockProviderBadState.tla` captures the shared `BlockProviderExecutor` failure path:
an unrecoverable provider error records the exception, fails every outstanding Future with a
`BadStateException`, and rejects later submissions while preserving already terminal tasks.
The runtime probe calls `set_bad_state_and_fail_all` on a small concrete subclass.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslBlockProviderBadState.cfg models/executors/ParslBlockProviderBadState.tla
```

`ParslBlockProviderBadStateOrdering.tla` refines that path with iteration order. The current
implementation calls `set_exception` on every task Future without checking `done()`: a completed
Future can raise `InvalidStateError` and prevent later pending tasks from being failed. TLC finds
the two-state counterexample; the fixed branch skips terminal Futures. The runtime probe uses a
completed entry followed by a pending entry to reproduce the partial failure sweep.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslBlockProviderBadStateOrderingCurrent.cfg models/executors/ParslBlockProviderBadStateOrdering.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslBlockProviderBadStateOrderingFixed.cfg models/executors/ParslBlockProviderBadStateOrdering.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_block_provider_bad_state_order_runtime.py -v
```

`ParslBlockProviderBadStateMutation.tla` models callback mutation during the same failure sweep.
`Future.set_exception()` runs callbacks synchronously, so a callback that mutates `_tasks` can
make the live dictionary iterator raise `RuntimeError`, leaving another original task pending.
The fixed branch iterates a snapshot. The runtime probe registers exactly this callback mutation.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslBlockProviderBadStateMutationCurrent.cfg models/executors/ParslBlockProviderBadStateMutation.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslBlockProviderBadStateMutationFixed.cfg models/executors/ParslBlockProviderBadStateMutation.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_block_provider_bad_state_mutation_runtime.py -v
```

`ParslHtexManagerSelection.tla` abstracts the two manager selectors in
`high_throughput/manager_selector.py`. Random selection is modeled as any permutation of ready
managers; block-ID selection preserves the source ordering rule, including managers with no block
ID and lexicographic block IDs. The runtime probe invokes both concrete selector classes.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexManagerSelection.cfg models/executors/ParslHtexManagerSelection.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexManagerSelectionBlock.cfg models/executors/ParslHtexManagerSelection.tla
```

`ParslJobStatusOutputSummary.tla` models the concrete output-file behavior of
`JobStatus.stdout_summary` and `stderr_summary`: a missing path/file yields no output, files at
or below 2048 bytes are returned in full, and larger files preserve only the head and tail with
an ellipsis marker. `tests/test_job_status_output_summary_runtime.py` checks these boundaries
against real temporary files.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslJobStatusOutputSummary.cfg models/executors/ParslJobStatusOutputSummary.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslJobStatusOutputSummaryLarge.cfg models/executors/ParslJobStatusOutputSummary.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslJobStatusOutputSummaryMissing.cfg models/executors/ParslJobStatusOutputSummary.tla
```

`ParslJobStatusOutputReadError.tla` models the exception-policy mismatch between
`JobStatus.stdout` and `stdout_summary`/`stderr_summary`: the former catches every read error,
while the summaries currently catch only `FileNotFoundError`. TLC finds the three-state current
counterexample for a permission error; the fixed branch normalizes it to no output. The runtime
probe patches `open()` to raise `PermissionError` and checks both properties.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslJobStatusOutputReadErrorCurrent.cfg models/executors/ParslJobStatusOutputReadError.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslJobStatusOutputReadErrorFixed.cfg models/executors/ParslJobStatusOutputReadError.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_job_status_output_read_error_runtime.py -v
```

`ParslHtexManagerDrain.tla` models `Interchange.expire_drained_managers`. A present draining
manager with no tasks receives the drained reply and is removed from both bookkeeping sets. The
current configuration exposes the unchecked `_ready_managers[manager_id]` lookup when an
interesting set contains a stale manager ID; the fixed configuration ignores that ID. The runtime
probe reproduces the current `KeyError` and checks the normal drain path.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexManagerDrainCurrent.cfg models/executors/ParslHtexManagerDrain.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexManagerDrainFixed.cfg models/executors/ParslHtexManagerDrain.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexManagerDrainPresent.cfg models/executors/ParslHtexManagerDrain.tla
```

The runtime probe is `tests/test_htex_manager_drain_runtime.py`; this stale-manager boundary is
recorded as BUG-125.

`ParslHtexMonitoringMessage.tla` covers a manager result batch containing a monitoring payload.
With monitoring enabled the payload is forwarded; the current disabled-monitoring path asserts
that a radio exists and can crash, while the fixed path ignores the optional payload without
changing task bookkeeping. The runtime probe sends the real pickled multipart message.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexMonitoringMessageCurrent.cfg models/executors/ParslHtexMonitoringMessage.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexMonitoringMessageFixed.cfg models/executors/ParslHtexMonitoringMessage.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexMonitoringMessageEnabled.cfg models/executors/ParslHtexMonitoringMessage.tla
```

`ParslHtexMonitoringBatchContinuation.tla` refines this boundary to a mixed batch: an optional
monitoring frame is followed by a valid task result. The current disabled-monitoring assertion
aborts before the task result is handled; the candidate fixed path ignores the optional frame and
continues. The runtime probe sends both real pickled payloads in one multipart message.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexMonitoringBatchContinuationCurrent.cfg models/executors/ParslHtexMonitoringBatchContinuation.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexMonitoringBatchContinuationFixed.cfg models/executors/ParslHtexMonitoringBatchContinuation.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_htex_monitoring_batch_continuation_runtime.py -v
```

`ParslHtexManagerLoss.tla` refines manager-loss handling across the two HTEX components: heartbeat
expiry in the interchange emits a synthetic result envelope for each in-flight task, and the
executor result worker resolves the matching Future with `ManagerLost`. The current regression
branch drops that envelope and violates `ExpiredTaskSafety` after 4 states; the fixed branch
delivers the failure and checks 7 states. `tests/test_htex_manager_loss_runtime.py` drives the
real expiry and result-worker path and verifies the Future exception.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexManagerLossCurrent.cfg models/executors/ParslHtexManagerLoss.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexManagerLossFixed.cfg models/executors/ParslHtexManagerLoss.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_htex_manager_loss_runtime.py -v
```

`ParslHtexUnknownManagerMessage.tla` checks the identity guard before processing manager traffic:
unknown heartbeat and result messages are ignored without a reply, task update, or ready-manager
mutation; registration remains the only message that can create a manager record. Runtime probes
exercise both unknown heartbeat and unknown result messages.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexUnknownManagerHeartbeat.cfg models/executors/ParslHtexUnknownManagerMessage.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexUnknownManagerResult.cfg models/executors/ParslHtexUnknownManagerMessage.tla
```

`ParslHtexManagerTaskAdmission.tla` connects manager registration to task queue admission. A
queued task may exist before a manager registers, but dispatch must wait for a ready manager;
heartbeat expiry then loses a running attempt and enables retry. During source review, the first
version of this model incorrectly allowed the current branch to dispatch without a manager. The
actual `Interchange.process_tasks_to_send` guard requires a non-empty `interesting_managers` set,
so both configurations now enforce the ready-manager precondition. TLC still checks the retry and
late-result paths; `USE_FIXED=TRUE` rejects late results from the lost attempt.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexManagerTaskAdmissionCurrent.cfg models/executors/ParslHtexManagerTaskAdmission.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexManagerTaskAdmissionFixed.cfg models/executors/ParslHtexManagerTaskAdmission.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_htex_manager_selection_runtime.py tests/test_htex_submit_runtime.py tests/test_htex_heartbeat_runtime.py tests/test_htex_manager_loss_runtime.py tests/test_retry_timeout_runtime.py -v
```
`ParslScaleInCancelShape.tla` covers the provider/executor cancellation contract. The current
`BlockProviderExecutor.scale_in` path asserts that the provider returns one boolean per requested
job; a short response raises before successful cancellations can be retained. The fixed branch
keeps the successful prefix and exposes a partial cancellation outcome. The runtime probe invokes
the real executor method with a provider double returning one result for two requested blocks.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslScaleInCancelShapeCurrent.cfg models/executors/ParslScaleInCancelShape.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslScaleInCancelShapeFixed.cfg models/executors/ParslScaleInCancelShape.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_scale_in_cancel_shape_runtime.py -v
```

`ParslProviderStatusShape.tla` covers the complementary status-poll contract. The current
`BlockProviderExecutor.status` mapping assumes one `JobStatus` for every requested block; a short
provider response raises `IndexError` and aborts the poll. The fixed branch retains the returned
statuses and represents missing entries as an explicit partial observation. The runtime probe
invokes the real status facade with a provider returning one status for two jobs.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslProviderStatusShapeCurrent.cfg models/executors/ParslProviderStatusShape.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslProviderStatusShapeFixed.cfg models/executors/ParslProviderStatusShape.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_provider_status_shape_runtime.py -v
```

`ParslBadStateTaskMutation.tla` covers executor failure fan-out. The current implementation can
raise `dictionary changed size during iteration` when a synchronous Future callback removes a
task entry; the fixed branch snapshots task entries before completing them. This is BUG-088 and
is exercised by `tests/test_bad_state_task_mutation_runtime.py`.

`ParslHeartbeatClockRollback.tla` models HTEX manager expiry with separate wall and monotonic
clocks. The current branch can keep an overdue manager alive after a backward system-clock step;
the fixed branch expires based on monotonic age. BUG-089 is exercised by the backward-clock probe
in `tests/test_heartbeat_clock_jump_runtime.py`.

`ParslResultsIncomingCloseRace.tla` refines the result-queue close boundary. The current
`ResultsIncoming.get()` can poll a socket already closed by `close()`; the fixed branch makes that
call a no-message no-op. This candidate issue is recorded as BUG-091 and tested by
`tests/test_results_incoming_close_race_runtime.py`.
