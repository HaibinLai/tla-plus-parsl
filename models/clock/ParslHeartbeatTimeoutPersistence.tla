--------------------------- MODULE ParslHeartbeatTimeoutPersistence ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Cross-layer logical-time model for HTEX liveness and task completion.
 *
 * The interchange expires a manager only when wall-clock age is strictly
 * greater than heartbeat_threshold.  A running task can independently reach
 * its task deadline.  A completion already in flight after either terminal
 * observation must be stale; otherwise a late worker result can overwrite the
 * timeout/lost status that monitoring persists.
 ***************************************************************************)

CONSTANTS HEARTBEAT_THRESHOLD, TASK_TIMEOUT, MAX_TIME, USE_FIXED

ManagerStates == {"up", "lost"}
TaskStates == {"pending", "running", "succeeded", "timed_out", "lost"}
EventStates == {"none", "queued", "persisted"}
Statuses == {"none", "succeeded", "timed_out", "lost"}

VARIABLES now, lastHeartbeat, manager, task, deadline,
          lateResult, eventState, eventStatus, dbStatus
vars == <<now, lastHeartbeat, manager, task, deadline,
           lateResult, eventState, eventStatus, dbStatus>>

Init ==
    /\ HEARTBEAT_THRESHOLD > 0
    /\ TASK_TIMEOUT > 0
    /\ MAX_TIME >= HEARTBEAT_THRESHOLD + TASK_TIMEOUT + 1
    /\ USE_FIXED \in BOOLEAN
    /\ now = 0
    /\ lastHeartbeat = 0
    /\ manager = "up"
    /\ task = "pending"
    /\ deadline = 0
    /\ lateResult = "none"
    /\ eventState = "none"
    /\ eventStatus = "none"
    /\ dbStatus = "none"

Tick ==
    /\ now < MAX_TIME
    /\ now' = now + 1
    /\ UNCHANGED <<lastHeartbeat, manager, task, deadline,
                    lateResult, eventState, eventStatus, dbStatus>>

Heartbeat ==
    /\ manager = "up"
    /\ lastHeartbeat' = now
    /\ UNCHANGED <<now, manager, task, deadline,
                    lateResult, eventState, eventStatus, dbStatus>>

StartTask ==
    /\ task = "pending"
    /\ manager = "up"
    /\ task' = "running"
    /\ deadline' = now + TASK_TIMEOUT
    /\ UNCHANGED <<now, lastHeartbeat, manager,
                    lateResult, eventState, eventStatus, dbStatus>>

ExpireManager ==
    /\ manager = "up"
    /\ now - lastHeartbeat > HEARTBEAT_THRESHOLD
    /\ manager' = "lost"
    /\ task' = IF task = "running" THEN "lost" ELSE task
    /\ UNCHANGED <<now, lastHeartbeat, deadline,
                    lateResult, eventState, eventStatus, dbStatus>>

TimeoutTask ==
    /\ task = "running"
    /\ now >= deadline
    /\ task' = "timed_out"
    /\ UNCHANGED <<now, lastHeartbeat, manager, deadline,
                    lateResult, eventState, eventStatus, dbStatus>>

CompleteTask ==
    /\ task = "running"
    /\ manager = "up"
    /\ now < deadline
    /\ task' = "succeeded"
    /\ UNCHANGED <<now, lastHeartbeat, manager, deadline,
                    lateResult, eventState, eventStatus, dbStatus>>

LateComplete ==
    /\ task \in {"timed_out", "lost"}
    /\ IF USE_FIXED
       THEN /\ lateResult' = "stale"
            /\ UNCHANGED task
       ELSE /\ lateResult' = "accepted"
            /\ task' = "succeeded"
    /\ UNCHANGED <<now, lastHeartbeat, manager, deadline,
                    eventState, eventStatus, dbStatus>>

Emit ==
    /\ task \in {"succeeded", "timed_out", "lost"}
    /\ eventState = "none"
    /\ eventState' = "queued"
    /\ eventStatus' = task
    /\ UNCHANGED <<now, lastHeartbeat, manager, task, deadline,
                    lateResult, dbStatus>>

Persist ==
    /\ eventState = "queued"
    /\ eventState' = "persisted"
    /\ dbStatus' = eventStatus
    /\ UNCHANGED <<now, lastHeartbeat, manager, task, deadline,
                    lateResult, eventStatus>>

Next ==
    \/ Tick
    \/ Heartbeat
    \/ StartTask
    \/ ExpireManager
    \/ TimeoutTask
    \/ CompleteTask
    \/ LateComplete
    \/ Emit
    \/ Persist
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ now \in 0..MAX_TIME
    /\ lastHeartbeat \in 0..MAX_TIME
    /\ manager \in ManagerStates
    /\ task \in TaskStates
    /\ deadline \in 0..(MAX_TIME + TASK_TIMEOUT)
    /\ lateResult \in {"none", "accepted", "stale"}
    /\ eventState \in EventStates
    /\ eventStatus \in Statuses
    /\ dbStatus \in Statuses

StrictHeartbeatSafety ==
    manager = "lost" => now - lastHeartbeat > HEARTBEAT_THRESHOLD

TerminalDatabaseSafety ==
    dbStatus = "succeeded" => task = "succeeded"

StaleCompletionSafety ==
    task \in {"timed_out", "lost"} => lateResult \in {"none", "stale"}

NoAcceptedLateCompletion ==
    lateResult # "accepted"

=============================================================================
