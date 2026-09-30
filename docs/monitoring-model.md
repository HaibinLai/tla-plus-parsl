# Monitoring model map

This page records how the bounded monitoring models correspond to the current Parsl source
tree. The models intentionally separate a logical task from physical tries and from the
asynchronous database write.

## Source-to-model mapping

| Parsl implementation | Model abstraction |
| --- | --- |
| parsl/dataflow/dflow.py::_send_task_info and _update_task_state | logicalStatus, logicalVersion, and EmitEvent in ParslMonitoringTaskRetry.tla |
| parsl/monitoring/message_type.py (TASK_INFO, WORKFLOW_INFO, WORKER_TASK_INFO) | priority/resource event classes in ParslMonitoringDB.tla and ParslMonitoringTaskRetry.tla |
| parsl/monitoring/db_manager.py::DatabaseManager.start | queue draining, deferred worker messages, and task/try row admission |
| db_manager.py::_insert and _update | WriteSuccess, bounded retry, permanent-error, and bookkeeping models |
| db_manager.py::_get_messages_in_batch | ParslMonitoringBatch.tla and ParslMonitoringBatchClock.tla |
| DataFlowKernel.cleanup workflow-end message | workflow insert/end bookkeeping models |

The key implementation detail is that TASK_INFO is both a logical task update and the source
of a physical try row. A worker message can arrive first, so DatabaseManager.start defers one
worker message per task/try until the corresponding task message has been inserted. This is
represented by the deferred queue in the monitoring models rather than by collapsing all events
into one state variable.

## Safety claims checked

The monitoring models check:

- task and try attempt bounds;
- database version/high-water-mark consistency;
- terminal task status stability under queue reordering;
- stale old-attempt events cannot replace a newer terminal row;
- failed inserts do not advance bookkeeping markers;
- persistent database errors terminate or retain work under a bounded policy;
- closing the manager does not silently discard queued priority messages.

The source currently retries sqlalchemy.exc.OperationalError in _insert and _update with
an unbounded loop and a fixed one-second sleep. That behavior is deliberately represented by
the Current configurations for the persistent-retry models; the Fixed configurations use a
bounded retry/dead-letter outcome. The ledger entries for these paths are source/runtime
findings, not claims that the model alone proves a production defect in every database setup.

## Running the focused model set

    java -cp tla2tools.jar tlc2.TLC \
      -config models/monitoring/ParslMonitoringTaskRetry.cfg \
      models/monitoring/ParslMonitoringTaskRetry.tla

    java -cp tla2tools.jar tlc2.TLC \
      -config models/monitoring/ParslMonitoringDB.cfg \
      models/monitoring/ParslMonitoringDB.tla

The repository sweep also runs current/fixed variants for reordering, deferred messages,
batching, shutdown, insert/update bookkeeping, and persistent retry.

`ParslMonitoringVersionedBatch.tla` combines transaction atomicity with versioned delivery. A
two-event batch can fail after its first write, and a late version-1 event can arrive after
version 2 is committed. The fixed branch restores the transaction snapshot on batch failure and
keeps the database high-water mark at version 2; TLC checks 100,001 simulated states.

`ParslMonitoringBatchThree.tla` extends the transaction boundary to three events. The writer
fails after the second event; the current branch leaves those partial rows visible, while the
fixed branch restores its pre-batch snapshot. `AbortAtomicity` and `CommitStability` capture the
database safety contract.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringBatchThreeCurrent.cfg models/monitoring/ParslMonitoringBatchThree.tla
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringBatchThreeFixed.cfg models/monitoring/ParslMonitoringBatchThree.tla
```
