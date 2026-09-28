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
