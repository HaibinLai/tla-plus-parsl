--------------------------- MODULE ParslTimeoutMonitoring ---------------------------
EXTENDS Naturals, Integers

(***************************************************************************
 * Logical time, worker heartbeat expiry, task timeout, and monitoring.
 *
 * A task can become timed out or lost while a worker completion is still in
 * flight.  The current branch accepts that late completion and can persist a
 * succeeded monitoring row after timeout.  The fixed branch classifies the
 * completion as stale and keeps the terminal timeout/lost state stable.
 ***************************************************************************)

CONSTANTS MAX_TIME, HEARTBEAT_TIMEOUT, TASK_TIMEOUT, USE_FIXED

ManagerStates == {"up", "expired"}
TaskStates == {"pending", "running", "succeeded", "timed_out", "lost"}
EventStates == {"none", "queued", "persisted"}
Statuses == {"none", "pending", "running", "succeeded", "timed_out", "lost"}

VARIABLES now, lastHeartbeat, manager, task, deadline,
          timedOutSeen, lostSeen, lateResult, eventState,
          eventStatus, dbStatus
vars == <<now, lastHeartbeat, manager, task, deadline,
           timedOutSeen, lostSeen, lateResult, eventState,
           eventStatus, dbStatus>>

Init ==
    /\ MAX_TIME >= 3
    /\ HEARTBEAT_TIMEOUT > 0
    /\ TASK_TIMEOUT > 0
    /\ USE_FIXED \in BOOLEAN
    /\ now = 0
    /\ lastHeartbeat = 0
    /\ manager = "up"
    /\ task = "pending"
    /\ deadline = 0
    /\ timedOutSeen = FALSE
    /\ lostSeen = FALSE
    /\ lateResult = "none"
    /\ eventState = "none"
    /\ eventStatus = "none"
    /\ dbStatus = "none"

Tick ==
    /\ now < MAX_TIME
    /\ now' = now + 1
    /\ UNCHANGED <<lastHeartbeat, manager, task, deadline,
                    timedOutSeen, lostSeen, lateResult, eventState,
                    eventStatus, dbStatus>>

Heartbeat ==
    /\ manager = "up"
    /\ lastHeartbeat' = now
    /\ UNCHANGED <<now, manager, task, deadline, timedOutSeen,
                    lostSeen, lateResult, eventState, eventStatus, dbStatus>>

ExpireManager ==
    /\ manager = "up"
    /\ now - lastHeartbeat >= HEARTBEAT_TIMEOUT
    /\ manager' = "expired"
    /\ task' = IF task = "running" THEN "lost" ELSE task
    /\ lostSeen' = IF task = "running" THEN TRUE ELSE lostSeen
    /\ UNCHANGED <<now, lastHeartbeat, deadline, timedOutSeen,
                    lateResult, eventState, eventStatus, dbStatus>>

StartTask ==
    /\ task = "pending"
    /\ manager = "up"
    /\ task' = "running"
    /\ deadline' = now + TASK_TIMEOUT
    /\ UNCHANGED <<now, lastHeartbeat, manager, timedOutSeen,
                    lostSeen, lateResult, eventState, eventStatus, dbStatus>>

CompleteTask ==
    /\ task = "running"
    /\ manager = "up"
    /\ now < deadline
    /\ task' = "succeeded"
    /\ UNCHANGED <<now, lastHeartbeat, manager, deadline, timedOutSeen,
                    lostSeen, lateResult, eventState, eventStatus, dbStatus>>

TimeoutTask ==
    /\ task = "running"
    /\ now >= deadline
    /\ task' = "timed_out"
    /\ timedOutSeen' = TRUE
    /\ UNCHANGED <<now, lastHeartbeat, manager, deadline,
                    lostSeen, lateResult, eventState, eventStatus, dbStatus>>

LateComplete ==
    /\ task \in {"timed_out", "lost"}
    /\ IF USE_FIXED
       THEN /\ lateResult' = "stale"
            /\ UNCHANGED task
       ELSE /\ task' = "succeeded"
            /\ lateResult' = "accepted"
    /\ UNCHANGED <<now, lastHeartbeat, manager, deadline, timedOutSeen,
                    lostSeen, eventState, eventStatus, dbStatus>>

EmitStatus ==
    /\ task \in {"succeeded", "timed_out", "lost"}
    /\ eventState = "none"
    /\ eventState' = "queued"
    /\ eventStatus' = task
    /\ UNCHANGED <<now, lastHeartbeat, manager, task, deadline,
                    timedOutSeen, lostSeen, lateResult, dbStatus>>

PersistStatus ==
    /\ eventState = "queued"
    /\ eventState' = "persisted"
    /\ dbStatus' = eventStatus
    /\ UNCHANGED <<now, lastHeartbeat, manager, task, deadline,
                    timedOutSeen, lostSeen, lateResult, eventStatus>>

Next ==
    \/ Tick
    \/ Heartbeat
    \/ ExpireManager
    \/ StartTask
    \/ CompleteTask
    \/ TimeoutTask
    \/ LateComplete
    \/ EmitStatus
    \/ PersistStatus
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ now \in 0..MAX_TIME
    /\ lastHeartbeat \in 0..MAX_TIME
    /\ manager \in ManagerStates
    /\ task \in TaskStates
    /\ deadline \in 0..(MAX_TIME + TASK_TIMEOUT)
    /\ timedOutSeen \in BOOLEAN
    /\ lostSeen \in BOOLEAN
    /\ lateResult \in {"none", "accepted", "stale"}
    /\ eventState \in EventStates
    /\ eventStatus \in Statuses
    /\ dbStatus \in Statuses

ClockSafety ==
    /\ lastHeartbeat <= now
    /\ manager = "expired" => now - lastHeartbeat >= HEARTBEAT_TIMEOUT

TerminalCauseSafety ==
    /\ timedOutSeen => dbStatus # "succeeded"
    /\ lostSeen => dbStatus # "succeeded"

DatabaseTaskSafety ==
    dbStatus = "succeeded" => task = "succeeded"

StaleLateResultSafety ==
    task \in {"timed_out", "lost"} => lateResult \in {"none", "stale"}

=============================================================================
