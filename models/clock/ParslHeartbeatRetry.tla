--------------------------- MODULE ParslHeartbeatRetry ---------------------------
EXTENDS Naturals, Integers

(***************************************************************************
 * Heartbeat expiry and task retry on two clock domains.
 *
 * now is monotonic logical time. wallClock is an observable wall clock
 * that may move backwards. The current branch uses wallClock for manager
 * expiry and accepts a late completion after timeout; the fixed branch uses
 * monotonic age and classifies that completion as stale.
 **************************************************************************)

CONSTANTS MAX_TIME, HEARTBEAT_TIMEOUT, TASK_TIMEOUT, MAX_RETRIES,
          USE_MONOTONIC, USE_FIXED

ManagerStates == {"up", "expired"}
TaskStates == {"pending", "running", "succeeded", "timed_out", "lost"}
AttemptStates == {"absent", "running", "completed", "timed_out", "lost"}
ResultStates == {"none", "sent", "delivered", "stale"}

VARIABLES now, wallClock, lastHeartbeat, lastWallHeartbeat, manager,
          task, attempt, attemptState, deadline, future, result,
          lateResult

vars == <<now, wallClock, lastHeartbeat, lastWallHeartbeat, manager,
           task, attempt, attemptState, deadline, future, result,
           lateResult>>

Init ==
    /\ MAX_TIME >= 4
    /\ HEARTBEAT_TIMEOUT > 0
    /\ TASK_TIMEOUT > 0
    /\ MAX_RETRIES >= 1
    /\ USE_MONOTONIC \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ now = 0
    /\ wallClock = 0
    /\ lastHeartbeat = 0
    /\ lastWallHeartbeat = 0
    /\ manager = "up"
    /\ task = "pending"
    /\ attempt = 0
    /\ attemptState = "absent"
    /\ deadline = -1
    /\ future = "unresolved"
    /\ result = "none"
    /\ lateResult = "none"

Tick ==
    /\ now < MAX_TIME
    /\ now' = now + 1
    /\ wallClock' = wallClock + 1
    /\ UNCHANGED <<lastHeartbeat, lastWallHeartbeat, manager, task,
                    attempt, attemptState, deadline, future, result,
                    lateResult>>

RollbackWallClock ==
    /\ manager = "up"
    /\ wallClock > 0
    /\ wallClock' = wallClock - 1
    /\ UNCHANGED <<now, lastHeartbeat, lastWallHeartbeat, manager, task,
                    attempt, attemptState, deadline, future, result,
                    lateResult>>

Heartbeat ==
    /\ manager = "up"
    /\ lastHeartbeat' = now
    /\ lastWallHeartbeat' = wallClock
    /\ UNCHANGED <<now, wallClock, manager, task, attempt, attemptState,
                    deadline, future, result, lateResult>>

StartAttempt ==
    /\ manager = "up"
    /\ task = "pending"
    /\ attemptState = "absent"
    /\ task' = "running"
    /\ attemptState' = "running"
    /\ deadline' = now + TASK_TIMEOUT
    /\ UNCHANGED <<now, wallClock, lastHeartbeat, lastWallHeartbeat,
                    manager, attempt, future, result, lateResult>>

ExpireManager ==
    /\ manager = "up"
    /\ (IF USE_MONOTONIC
        THEN now - lastHeartbeat >= HEARTBEAT_TIMEOUT
        ELSE wallClock - lastWallHeartbeat >= HEARTBEAT_TIMEOUT)
    /\ manager' = "expired"
    /\ task' = IF task = "running" THEN "lost" ELSE task
    /\ attemptState' = IF attemptState = "running" THEN "lost" ELSE attemptState
    /\ UNCHANGED <<now, wallClock, lastHeartbeat, lastWallHeartbeat,
                    attempt, deadline, future, result, lateResult>>

CompleteAttempt ==
    /\ manager = "up"
    /\ task = "running"
    /\ attemptState = "running"
    /\ now < deadline
    /\ task' = "succeeded"
    /\ attemptState' = "completed"
    /\ future' = "resolved"
    /\ UNCHANGED <<now, wallClock, lastHeartbeat, lastWallHeartbeat,
                    manager, attempt, deadline, result, lateResult>>

TimeoutAttempt ==
    /\ task = "running"
    /\ attemptState = "running"
    /\ now >= deadline
    /\ task' = "timed_out"
    /\ attemptState' = "timed_out"
    /\ future' = "unresolved"
    /\ UNCHANGED <<now, wallClock, lastHeartbeat, lastWallHeartbeat,
                    manager, attempt, deadline, result, lateResult>>

RetryAttempt ==
    /\ task \in {"timed_out", "lost"}
    /\ attempt < MAX_RETRIES
    /\ task' = "pending"
    /\ attempt' = attempt + 1
    /\ attemptState' = "absent"
    /\ UNCHANGED <<now, wallClock, lastHeartbeat, lastWallHeartbeat,
                    manager, deadline, future, result, lateResult>>

SendLateResult ==
    /\ attemptState \in {"timed_out", "lost"}
    /\ result = "none"
    /\ result' = "sent"
    /\ UNCHANGED <<now, wallClock, lastHeartbeat, lastWallHeartbeat,
                    manager, task, attempt, attemptState, deadline,
                    future, lateResult>>

DeliverLateResult ==
    /\ result = "sent"
    /\ result' = "delivered"
    /\ IF USE_FIXED
       THEN /\ lateResult' = "stale"
            /\ UNCHANGED <<task, future>>
       ELSE /\ lateResult' = "accepted"
            /\ task' = "succeeded"
            /\ future' = "resolved"
    /\ UNCHANGED <<now, wallClock, lastHeartbeat, lastWallHeartbeat,
                    manager, attempt, attemptState, deadline>>

Next ==
    \/ Tick
    \/ RollbackWallClock
    \/ Heartbeat
    \/ StartAttempt
    \/ ExpireManager
    \/ CompleteAttempt
    \/ TimeoutAttempt
    \/ RetryAttempt
    \/ SendLateResult
    \/ DeliverLateResult
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ now \in 0..MAX_TIME
    /\ wallClock \in 0..(MAX_TIME + 1)
    /\ lastHeartbeat \in 0..MAX_TIME
    /\ lastWallHeartbeat \in 0..(MAX_TIME + 1)
    /\ manager \in ManagerStates
    /\ task \in TaskStates
    /\ attempt \in 0..MAX_RETRIES
    /\ attemptState \in AttemptStates
    /\ deadline \in -1..(MAX_TIME + TASK_TIMEOUT)
    /\ future \in {"unresolved", "resolved"}
    /\ result \in ResultStates
    /\ lateResult \in {"none", "accepted", "stale"}

MonotonicTimeSafety == now >= lastHeartbeat

ExpirySafety ==
    manager = "expired" =>
        (IF USE_MONOTONIC
         THEN now - lastHeartbeat >= HEARTBEAT_TIMEOUT
         ELSE wallClock - lastWallHeartbeat >= HEARTBEAT_TIMEOUT)

RetryBound == attempt <= MAX_RETRIES

NoAcceptedLateResult ==
    lateResult # "accepted"

TerminalSafety ==
    task \in {"timed_out", "lost"} => lateResult \in {"none", "stale"}

=============================================================================
