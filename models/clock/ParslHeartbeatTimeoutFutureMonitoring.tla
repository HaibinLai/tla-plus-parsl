--------------------------- MODULE ParslHeartbeatTimeoutFutureMonitoring ---------------------------
EXTENDS Naturals, Integers

(***************************************************************************
 * A small cross-layer clock model.  HTEX-style heartbeat expiry and a task
 * timeout use elapsed time while a completion may be in flight.  The Current
 * branch uses wall-clock age for worker expiry and accepts a completion after a
 * terminal timeout; the Fixed branch uses monotonic age and treats that frame
 * as stale.  Monitoring follows the Future terminal state.
 ***************************************************************************)

CONSTANTS HEARTBEAT_LIMIT, TASK_LIMIT, MAX_TICKS, USE_FIXED

WorkerStates == {"active", "expired"}
TaskStates == {"pending", "running", "timed_out", "succeeded"}
FutureStates == {"pending", "timed_out", "succeeded"}
MonitorStates == {"none", "timed_out", "succeeded"}

VARIABLES wallNow, monoNow, lastWallHeartbeat, lastMonoHeartbeat,
          worker, task, future, monitor, deadline, timedOutSeen
vars == <<wallNow, monoNow, lastWallHeartbeat, lastMonoHeartbeat,
           worker, task, future, monitor, deadline, timedOutSeen>>

Init ==
    /\ HEARTBEAT_LIMIT > 0
    /\ TASK_LIMIT > 0
    /\ MAX_TICKS >= HEARTBEAT_LIMIT + TASK_LIMIT
    /\ USE_FIXED \in BOOLEAN
    /\ wallNow = 0
    /\ monoNow = 0
    /\ lastWallHeartbeat = 0
    /\ lastMonoHeartbeat = 0
    /\ worker = "active"
    /\ task = "pending"
    /\ future = "pending"
    /\ monitor = "none"
    /\ deadline = 0
    /\ timedOutSeen = FALSE

Tick ==
    /\ worker = "active"
    /\ monoNow < MAX_TICKS
    /\ monoNow' = monoNow + 1
    /\ wallNow' = IF monoNow = 1 THEN -2 ELSE wallNow + 1
    /\ UNCHANGED <<lastWallHeartbeat, lastMonoHeartbeat, worker, task,
                    future, monitor, deadline, timedOutSeen>>

Heartbeat ==
    /\ worker = "active"
    /\ lastWallHeartbeat' = wallNow
    /\ lastMonoHeartbeat' = monoNow
    /\ UNCHANGED <<wallNow, monoNow, worker, task, future, monitor, deadline,
                    timedOutSeen>>

ExpireWorker ==
    /\ worker = "active"
    /\ IF USE_FIXED
          THEN monoNow - lastMonoHeartbeat >= HEARTBEAT_LIMIT
          ELSE wallNow - lastWallHeartbeat >= HEARTBEAT_LIMIT
    /\ worker' = "expired"
    /\ UNCHANGED <<wallNow, monoNow, lastWallHeartbeat, lastMonoHeartbeat,
                    task, future, monitor, deadline, timedOutSeen>>

StartTask ==
    /\ task = "pending"
    /\ worker = "active"
    /\ task' = "running"
    /\ deadline' = monoNow + TASK_LIMIT
    /\ UNCHANGED <<wallNow, monoNow, lastWallHeartbeat, lastMonoHeartbeat,
                    worker, future, monitor, timedOutSeen>>

TimeoutTask ==
    /\ task = "running"
    /\ monoNow >= deadline
    /\ task' = "timed_out"
    /\ future' = "timed_out"
    /\ monitor' = "timed_out"
    /\ timedOutSeen' = TRUE
    /\ UNCHANGED <<wallNow, monoNow, lastWallHeartbeat, lastMonoHeartbeat,
                    worker, deadline>>

LateCompletion ==
    /\ task = "timed_out"
    /\ IF USE_FIXED
          THEN /\ UNCHANGED <<task, future, monitor>>
          ELSE /\ task' = "succeeded"
               /\ future' = "succeeded"
               /\ monitor' = "succeeded"
    /\ UNCHANGED <<wallNow, monoNow, lastWallHeartbeat, lastMonoHeartbeat,
                    worker, deadline, timedOutSeen>>

Next ==
    \/ Tick
    \/ Heartbeat
    \/ ExpireWorker
    \/ StartTask
    \/ TimeoutTask
    \/ LateCompletion
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ wallNow \in -2..(MAX_TICKS + 1)
    /\ monoNow \in 0..MAX_TICKS
    /\ lastWallHeartbeat \in -2..(MAX_TICKS + 1)
    /\ lastMonoHeartbeat \in 0..MAX_TICKS
    /\ worker \in WorkerStates
    /\ task \in TaskStates
    /\ future \in FutureStates
    /\ monitor \in MonitorStates
    /\ deadline \in 0..(MAX_TICKS + TASK_LIMIT)
    /\ timedOutSeen \in BOOLEAN

HeartbeatExpirySafety ==
    worker = "expired" =>
        IF USE_FIXED
           THEN monoNow - lastMonoHeartbeat >= HEARTBEAT_LIMIT
           ELSE wallNow - lastWallHeartbeat >= HEARTBEAT_LIMIT

TimeoutTerminality ==
    timedOutSeen =>
        /\ future = "timed_out"
        /\ monitor = "timed_out"

MonitoringConsistency ==
    monitor = "succeeded" => future = "succeeded"

=============================================================================
