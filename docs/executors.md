# Executor and HTEX models

These models cover executor lifecycle, task execution, HTEX submission and result queues, worker
registration, heartbeats, command deadlines, ThreadExecutor, WorkQueue, TaskVine, Flux, and
RadicalPilot result handling.

Files live in [`models/executors/`](../models/executors/). The full TLC command list is in
[the overview](overview.md).

`ParslExecutorProviderLifecycle.tla` connects provider allocation, manager registration, free
worker slots, queued/running tasks, executor drain, and provider terminal cleanup. The current
configuration finds a `MinBlockSafety` counterexample when scale-in leaves an active provider
below `MIN_BLOCKS`; the fixed configuration enforces the floor and checks 161 states.

`ParslHeartbeatLateAck.tla` isolates the in-flight heartbeat race: a manager can expire before an
old heartbeat reaches the interchange. The current branch accepts that stale acknowledgement and
resurrects the manager, violating `ExpiryTerminal`; the fixed branch ignores it as stale. This
matches the manager-record lookup guard in HTEX `interchange.py` before processing messages.

Run this focused check with:

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHeartbeatLateAck.cfg models/executors/ParslHeartbeatLateAck.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHeartbeatLateAckFixed.cfg models/executors/ParslHeartbeatLateAck.tla
```
