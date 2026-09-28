# Clock and strategy models

`models/clock/` contains logical time, timeout timers, heartbeat age, and terminal timeout
scenarios. `models/strategy/` contains the focused scale-out/scale-in policy model with block and
idle limits.

`ParslTimedHeartbeat.tla` is the compact combined abstraction. It uses one logical clock for
heartbeat age and task deadlines, models manager expiry and task timeout separately, and allows a
late result after either event. `ParslTimedHeartbeat.cfg` intentionally violates `ResultSafety`
by accepting that late result; `ParslTimedHeartbeatFixed.cfg` classifies it as stale and passes all
six invariants (3,061 states generated, 848 distinct states).
