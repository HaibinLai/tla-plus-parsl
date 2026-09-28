--------------------------- MODULE ParslTimedHeartbeat ---------------------------
EXTENDS Naturals, Integers

(***************************************************************************
 * A compact time/heartbeat/timeout abstraction.
 *
 * `now` is the logical wall-clock used for both manager heartbeat age and a
 * task deadline.  A task can be lost by heartbeat expiry or rejected by its
 * own deadline.  A result can still arrive after either event; the current
 * branch accepts it, while the fixed branch classifies it as stale.
 ***************************************************************************)

CONSTANTS MAX_TIME, HEARTBEAT_TIMEOUT, TASK_TIMEOUT, USE_FIXED

ManagerStates == {"up", "expired"}
AttemptStates == {"absent", "running", "timed_out", "completed", "lost"}
FutureStates == {"unresolved", "resolved", "rejected"}
ResultStates == {"none", "sent", "delivered", "stale"}

VARIABLES now, managerState, lastHeartbeat, heartbeatPending,
          attemptState, attemptStart, attemptDeadline, futureState, resultState

vars == <<now, managerState, lastHeartbeat, heartbeatPending,
           attemptState, attemptStart, attemptDeadline, futureState, resultState>>

Init ==
    /\ MAX_TIME > 0
    /\ HEARTBEAT_TIMEOUT > 0
    /\ TASK_TIMEOUT > 0
    /\ now = 0
    /\ managerState = "up"
    /\ lastHeartbeat = 0
    /\ heartbeatPending = FALSE
    /\ attemptState = "absent"
    /\ attemptStart = 0
    /\ attemptDeadline = 0
    /\ futureState = "unresolved"
    /\ resultState = "none"

Tick ==
    /\ now < MAX_TIME
    /\ now' = now + 1
    /\ UNCHANGED <<managerState, lastHeartbeat, heartbeatPending,
                    attemptState, attemptStart, attemptDeadline,
                    futureState, resultState>>

SendHeartbeat ==
    /\ managerState = "up"
    /\ ~heartbeatPending
    /\ heartbeatPending' = TRUE
    /\ UNCHANGED <<now, managerState, lastHeartbeat, attemptState,
                    attemptStart, attemptDeadline, futureState, resultState>>

DeliverHeartbeat ==
    /\ managerState = "up"
    /\ heartbeatPending
    /\ heartbeatPending' = FALSE
    /\ lastHeartbeat' = now
    /\ UNCHANGED <<now, managerState, attemptState, attemptStart,
                    attemptDeadline, futureState, resultState>>

DropHeartbeat ==
    /\ heartbeatPending
    /\ heartbeatPending' = FALSE
    /\ UNCHANGED <<now, managerState, lastHeartbeat, attemptState,
                    attemptStart, attemptDeadline, futureState, resultState>>

ExpireManager ==
    /\ managerState = "up"
    /\ now - lastHeartbeat > HEARTBEAT_TIMEOUT
    /\ managerState' = "expired"
    /\ attemptState' = IF attemptState = "running" THEN "lost" ELSE attemptState
    /\ futureState' = IF attemptState = "running" THEN "rejected" ELSE futureState
    /\ UNCHANGED <<now, lastHeartbeat, heartbeatPending, attemptStart,
                    attemptDeadline, resultState>>

StartAttempt ==
    /\ managerState = "up"
    /\ attemptState = "absent"
    /\ futureState = "unresolved"
    /\ attemptState' = "running"
    /\ attemptStart' = now
    /\ attemptDeadline' = now + TASK_TIMEOUT
    /\ UNCHANGED <<now, managerState, lastHeartbeat, heartbeatPending,
                    futureState, resultState>>

CompleteAttempt ==
    /\ managerState = "up"
    /\ attemptState = "running"
    /\ now < attemptDeadline
    /\ attemptState' = "completed"
    /\ futureState' = "resolved"
    /\ UNCHANGED <<now, managerState, lastHeartbeat, heartbeatPending,
                    attemptStart, attemptDeadline, resultState>>

TimeoutAttempt ==
    /\ attemptState = "running"
    /\ now >= attemptDeadline
    /\ attemptState' = "timed_out"
    /\ futureState' = "rejected"
    /\ UNCHANGED <<now, managerState, lastHeartbeat, heartbeatPending,
                    attemptStart, attemptDeadline, resultState>>

SendResult ==
    /\ attemptState \in {"completed", "timed_out", "lost"}
    /\ resultState = "none"
    /\ resultState' = "sent"
    /\ UNCHANGED <<now, managerState, lastHeartbeat, heartbeatPending,
                    attemptState, attemptStart, attemptDeadline, futureState>>

DeliverResult ==
    /\ resultState = "sent"
    /\ resultState' = IF attemptState = "completed" \/ USE_FIXED THEN
                          IF attemptState = "completed" THEN "delivered" ELSE "stale"
                      ELSE "delivered"
    /\ futureState' = IF attemptState = "completed" \/ USE_FIXED
                      THEN IF attemptState = "completed" THEN "resolved" ELSE futureState
                      ELSE "resolved"
    /\ UNCHANGED <<now, managerState, lastHeartbeat, heartbeatPending,
                    attemptState, attemptStart, attemptDeadline>>

Next ==
    \/ Tick
    \/ SendHeartbeat
    \/ DeliverHeartbeat
    \/ DropHeartbeat
    \/ ExpireManager
    \/ StartAttempt
    \/ CompleteAttempt
    \/ TimeoutAttempt
    \/ SendResult
    \/ DeliverResult
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ now \in 0..MAX_TIME
    /\ managerState \in ManagerStates
    /\ lastHeartbeat \in 0..MAX_TIME
    /\ heartbeatPending \in BOOLEAN
    /\ attemptState \in AttemptStates
    /\ attemptStart \in 0..(MAX_TIME + TASK_TIMEOUT)
    /\ attemptDeadline \in 0..(MAX_TIME + TASK_TIMEOUT)
    /\ futureState \in FutureStates
    /\ resultState \in ResultStates

ClockSafety ==
    /\ lastHeartbeat <= now
    /\ attemptState = "running" => attemptStart <= now /\ attemptDeadline = attemptStart + TASK_TIMEOUT

HeartbeatExpirySafety ==
    managerState = "expired" => now - lastHeartbeat > HEARTBEAT_TIMEOUT

TimeoutSafety ==
    attemptState = "timed_out" => now >= attemptDeadline

ResultSafety ==
    /\ resultState = "delivered" => attemptState = "completed"
    /\ resultState = "stale" => attemptState # "completed"

FutureSafety ==
    /\ futureState = "resolved" => attemptState = "completed"
    /\ futureState = "rejected" => attemptState \in {"timed_out", "lost"}

=============================================================================
