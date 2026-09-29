# Clock and strategy models

`ParslHeartbeatClockRollback.tla` complements the forward-jump model with a backward system-clock
adjustment. The current wall-clock branch can reach the bounded horizon without expiring the
manager, while the monotonic fixed branch expires once elapsed time reaches the threshold.

`models/clock/` contains logical time, timeout timers, heartbeat age, and terminal timeout
scenarios. `models/strategy/` contains the focused scale-out/scale-in policy model with block and
idle limits.

`ParslPythonTimeoutParameter.tla` models the delay passed by the Python-app `timeout` decorator.
The current wrapper accepts a negative delay and immediately injects `AppTimeout` through
`threading.Timer`; the fixed branch rejects non-positive delays before execution. The runtime
probe calls the real decorator with a negative timeout.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/clock/ParslPythonTimeoutParameterCurrent.cfg models/clock/ParslPythonTimeoutParameter.tla
java -cp tla2tools.jar tlc2.TLC -config models/clock/ParslPythonTimeoutParameterFixed.cfg models/clock/ParslPythonTimeoutParameter.tla
java -cp tla2tools.jar tlc2.TLC -config models/clock/ParslPythonTimeoutParameterValid.cfg models/clock/ParslPythonTimeoutParameter.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_python_timeout_parameter_runtime.py -v
```

`ParslHeartbeatParameterValidation.tla` models HTEX heartbeat configuration admission. The
current executor stores a zero period or non-positive threshold and proceeds; the fixed branch
rejects those values before launching workers. The runtime probe constructs the real
`HighThroughputExecutor` with `heartbeat_period=0` and `heartbeat_threshold=-1`.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/clock/ParslHeartbeatParameterValidationCurrent.cfg models/clock/ParslHeartbeatParameterValidation.tla
java -cp tla2tools.jar tlc2.TLC -config models/clock/ParslHeartbeatParameterValidationFixed.cfg models/clock/ParslHeartbeatParameterValidation.tla
java -cp tla2tools.jar tlc2.TLC -config models/clock/ParslHeartbeatParameterValidationValid.cfg models/clock/ParslHeartbeatParameterValidation.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_heartbeat_parameter_validation_runtime.py -v
```

`ParslStrategyBlockCapacity.tla` isolates configuration admission for the strategy's overload
calculation. The current path accepts `nodes_per_block=0` and then divides by the zero capacity
when it tries to determine an additional-block request. The fixed branch rejects that
configuration before polling; a valid one-node configuration still emits a scale request. The
runtime probe invokes the real `Strategy._general_strategy` with a fake provider-backed executor.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/strategy/ParslStrategyBlockCapacityCurrent.cfg models/strategy/ParslStrategyBlockCapacity.tla
java -cp tla2tools.jar tlc2.TLC -config models/strategy/ParslStrategyBlockCapacityFixed.cfg models/strategy/ParslStrategyBlockCapacity.tla
java -cp tla2tools.jar tlc2.TLC -config models/strategy/ParslStrategyBlockCapacitySuccess.cfg models/strategy/ParslStrategyBlockCapacity.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_strategy_runtime.py -v
```

`ParslPeriodicTimer.tla` models the shared `parsl.utils.Timer` lifecycle used by the job-status
poller and periodic checkpointing. It captures the immediate first callback, periodic callbacks,
the fact that callback exceptions are logged without stopping the timer, and the quiescent
boundary after `close()`. `tests/test_periodic_timer_runtime.py` probes the same behavior against
the real timer implementation.

`ParslTimerIntervalValidation.tla` checks the timer parameter boundary. The current constructor
silently maps a negative interval to zero, creating a no-wait timer loop; the fixed branch rejects
negative input before starting its thread. The runtime probe confirms the current normalization
on the real `Timer` class.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/clock/ParslTimerIntervalValidationCurrent.cfg models/clock/ParslTimerIntervalValidation.tla
java -cp tla2tools.jar tlc2.TLC -config models/clock/ParslTimerIntervalValidationFixed.cfg models/clock/ParslTimerIntervalValidation.tla
java -cp tla2tools.jar tlc2.TLC -config models/clock/ParslTimerIntervalValidationValid.cfg models/clock/ParslTimerIntervalValidation.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_timer_interval_validation_runtime.py -v
```

`ParslTimeLimitedOpenTimeout.tla` connects the file wait loop to its open boundary. When the path
never appears, the current `time_limited_open` yields and exposes a raw `FileNotFoundError`; the
fixed branch returns an explicit timeout without attempting the open. The runtime probe uses a
missing temporary path and a zero-second polling horizon.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/clock/ParslTimeLimitedOpenTimeoutCurrent.cfg models/clock/ParslTimeLimitedOpenTimeout.tla
java -cp tla2tools.jar tlc2.TLC -config models/clock/ParslTimeLimitedOpenTimeoutFixed.cfg models/clock/ParslTimeLimitedOpenTimeout.tla
java -cp tla2tools.jar tlc2.TLC -config models/clock/ParslTimeLimitedOpenTimeoutSuccess.cfg models/clock/ParslTimeLimitedOpenTimeout.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_time_limited_open_timeout_runtime.py -v
```

`ParslTimerCloseTimeout.tla` refines the close boundary when a callback is still running. The
current `Timer.close(timeout=...)` returns `None` after a timed join even while the daemon thread
remains alive; the fixed branch represents that result as an explicit `closing` timeout rather
than a completed close. The runtime probe blocks the immediate callback and observes the real
thread after `close` returns.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/clock/ParslTimerCloseTimeoutCurrent.cfg models/clock/ParslTimerCloseTimeout.tla
java -cp tla2tools.jar tlc2.TLC -config models/clock/ParslTimerCloseTimeoutFixed.cfg models/clock/ParslTimerCloseTimeout.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_timer_close_timeout_runtime.py -v
```

`ParslWorkerContactTimeout.tla` models the HTEX worker-side clock: periodic heartbeat emission,
contact timestamp refresh on incoming messages, and self-stop when a no-message poll reaches the
heartbeat threshold. A message at the exact threshold wins because the source handles `POLLIN`
before checking the no-message timeout. The runtime probe also checks the pickled heartbeat and
drain control messages emitted by the real worker `Manager` class.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/clock/ParslWorkerContactTimeout.cfg models/clock/ParslWorkerContactTimeout.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_worker_pool_heartbeat_runtime.py -v
```

`ParslTimedHeartbeat.tla` is the compact combined abstraction. It uses one logical clock for
heartbeat age and task deadlines, models manager expiry and task timeout separately, and allows a
late result after either event. `ParslTimedHeartbeat.cfg` intentionally violates `ResultSafety`
by accepting that late result; `ParslTimedHeartbeatFixed.cfg` classifies it as stale and passes all
six invariants (3,061 states generated, 848 distinct states).

`ParslTimeoutMonitoring.tla` adds the monitoring database to that clock boundary. A late worker
completion after heartbeat expiry or task timeout can be emitted and persisted as `succeeded` in
the current branch; TLC finds the `TerminalCauseSafety` counterexample at depth 8 (553 states
generated). The fixed branch keeps the timeout/lost terminal cause and records the late result as
stale, checking 715 distinct states.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/clock/ParslTimeoutMonitoringCurrent.cfg models/clock/ParslTimeoutMonitoring.tla
java -cp tla2tools.jar tlc2.TLC -config models/clock/ParslTimeoutMonitoringFixed.cfg models/clock/ParslTimeoutMonitoring.tla
```

`Tick`, `Heartbeat`, `ExpireManager`, and `TimeoutTask` abstract the logical clock and HTEX
contact/deadline checks. `EmitStatus` and `PersistStatus` abstract DFK monitoring event and
database delivery. Runtime evidence comes from the heartbeat, retry/timeout, and monitoring
database probes under `tests/`.
