# Executor and HTEX models

These models cover executor lifecycle, task execution, HTEX submission and result queues, worker
registration, heartbeats, command deadlines, ThreadExecutor, WorkQueue, TaskVine, Flux, and
RadicalPilot result handling.

Files live in [`models/executors/`](../models/executors/). The full TLC command list is in
[the overview](overview.md).

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

`ParslRadicalPilotFailurePayload.tla` refines the RADICAL-Pilot callback mapping. If a failed
Python task has no serialized exception payload, the current callback passes a string to
`Future.set_exception`, which produces a callback-level `TypeError`; the fixed configuration wraps
the missing payload in a real `RuntimeError`. `test_radical_results_runtime.py` contains the
corresponding source-level probe.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslRadicalPilotFailurePayloadCurrent.cfg models/executors/ParslRadicalPilotFailurePayload.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslRadicalPilotFailurePayloadFixed.cfg models/executors/ParslRadicalPilotFailurePayload.tla
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

`ParslHtexMonitoringMessage.tla` covers a manager result batch containing a monitoring payload.
With monitoring enabled the payload is forwarded; the current disabled-monitoring path asserts
that a radio exists and can crash, while the fixed path ignores the optional payload without
changing task bookkeeping. The runtime probe sends the real pickled multipart message.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexMonitoringMessageCurrent.cfg models/executors/ParslHtexMonitoringMessage.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexMonitoringMessageFixed.cfg models/executors/ParslHtexMonitoringMessage.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexMonitoringMessageEnabled.cfg models/executors/ParslHtexMonitoringMessage.tla
```

`ParslHtexUnknownManagerMessage.tla` checks the identity guard before processing manager traffic:
unknown heartbeat and result messages are ignored without a reply, task update, or ready-manager
mutation; registration remains the only message that can create a manager record. Runtime probes
exercise both unknown heartbeat and unknown result messages.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexUnknownManagerHeartbeat.cfg models/executors/ParslHtexUnknownManagerMessage.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexUnknownManagerResult.cfg models/executors/ParslHtexUnknownManagerMessage.tla
```
