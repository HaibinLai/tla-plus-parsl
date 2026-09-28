--------------------------- MODULE ParslClock ---------------------------
EXTENDS Naturals, Integers

(***************************************************************************
 * A focused time model for one manager and one logical task.
 *
 * wallClock is the bounded monotonic wall-clock abstraction.  Heartbeats have
 * an explicit send/deliver/drop path, while attempts carry start/deadline
 * timestamps.  A result from an older physical attempt can arrive after a
 * timeout and is classified as stale rather than changing the Future.
 ***************************************************************************)

CONSTANTS WORKERS, MAX_RETRIES, MAX_TIME, HEARTBEAT_TIMEOUT, TASK_TIMEOUT

AttemptIds == 0..MAX_RETRIES
ManagerStates == {"up", "expired"}
AttemptStates == {"absent", "running", "timed_out", "completed", "lost"}
ResultStates == {"none", "sent", "delivered", "stale"}
FutureStates == {"unresolved", "resolved", "rejected"}

VARIABLES wallClock, managerState, lastHeartbeat, heartbeatInFlight,
          attemptState, attemptStart, attemptDeadline, currentAttempt,
          futureState, resultState

vars == <<wallClock, managerState, lastHeartbeat, heartbeatInFlight,
           attemptState, attemptStart, attemptDeadline, currentAttempt,
           futureState, resultState>>

Init ==
    /\ WORKERS # {}
    /\ MAX_RETRIES >= 0
    /\ MAX_TIME > 0
    /\ HEARTBEAT_TIMEOUT > 0
    /\ TASK_TIMEOUT > 0
    /\ wallClock = 0
    /\ managerState = "up"
    /\ lastHeartbeat = [w \in WORKERS |-> 0]
    /\ heartbeatInFlight = [w \in WORKERS |-> FALSE]
    /\ attemptState = [k \in AttemptIds |-> "absent"]
    /\ attemptStart = [k \in AttemptIds |-> -1]
    /\ attemptDeadline = [k \in AttemptIds |-> -1]
    /\ currentAttempt = 0
    /\ futureState = "unresolved"
    /\ resultState = [k \in AttemptIds |-> "none"]

Tick ==
    /\ wallClock < MAX_TIME
    /\ wallClock' = wallClock + 1
    /\ UNCHANGED <<managerState, lastHeartbeat, heartbeatInFlight,
                    attemptState, attemptStart, attemptDeadline,
                    currentAttempt, futureState, resultState>>

SendHeartbeat(w) ==
    /\ managerState = "up"
    /\ ~heartbeatInFlight[w]
    /\ heartbeatInFlight' = [heartbeatInFlight EXCEPT ![w] = TRUE]
    /\ UNCHANGED <<wallClock, managerState, lastHeartbeat,
                    attemptState, attemptStart, attemptDeadline,
                    currentAttempt, futureState, resultState>>

DeliverHeartbeat(w) ==
    /\ managerState = "up"
    /\ heartbeatInFlight[w]
    /\ heartbeatInFlight' = [heartbeatInFlight EXCEPT ![w] = FALSE]
    /\ lastHeartbeat' = [lastHeartbeat EXCEPT ![w] = wallClock]
    /\ UNCHANGED <<wallClock, managerState, attemptState, attemptStart,
                    attemptDeadline, currentAttempt, futureState, resultState>>

DropHeartbeat(w) ==
    /\ heartbeatInFlight[w]
    /\ heartbeatInFlight' = [heartbeatInFlight EXCEPT ![w] = FALSE]
    /\ UNCHANGED <<wallClock, managerState, lastHeartbeat,
                    attemptState, attemptStart, attemptDeadline,
                    currentAttempt, futureState, resultState>>

ExpireManager ==
    /\ managerState = "up"
    /\ \E w \in WORKERS : wallClock - lastHeartbeat[w] >= HEARTBEAT_TIMEOUT
    /\ managerState' = "expired"
    /\ attemptState' = [k \in AttemptIds |->
          IF attemptState[k] = "running" THEN "lost" ELSE attemptState[k]]
    /\ UNCHANGED <<wallClock, lastHeartbeat, heartbeatInFlight,
                    attemptStart, attemptDeadline, currentAttempt,
                    futureState, resultState>>

RecoverManager ==
    /\ managerState = "expired"
    /\ managerState' = "up"
    /\ lastHeartbeat' = [w \in WORKERS |-> wallClock]
    /\ UNCHANGED <<wallClock, heartbeatInFlight, attemptState,
                    attemptStart, attemptDeadline, currentAttempt,
                    futureState, resultState>>

StartAttempt(k) ==
    /\ managerState = "up"
    /\ k = currentAttempt
    /\ attemptState[k] = "absent"
    /\ attemptState' = [attemptState EXCEPT ![k] = "running"]
    /\ attemptStart' = [attemptStart EXCEPT ![k] = wallClock]
    /\ attemptDeadline' = [attemptDeadline EXCEPT ![k] = wallClock + TASK_TIMEOUT]
    /\ UNCHANGED <<wallClock, managerState, lastHeartbeat, heartbeatInFlight,
                    currentAttempt, futureState, resultState>>

CompleteAttempt(k) ==
    /\ k = currentAttempt
    /\ attemptState[k] = "running"
    /\ wallClock < attemptDeadline[k]
    /\ attemptState' = [attemptState EXCEPT ![k] = "completed"]
    /\ futureState' = "resolved"
    /\ UNCHANGED <<wallClock, managerState, lastHeartbeat, heartbeatInFlight,
                    attemptStart, attemptDeadline, currentAttempt, resultState>>

TimeoutAttempt(k) ==
    /\ k = currentAttempt
    /\ attemptState[k] = "running"
    /\ wallClock >= attemptDeadline[k]
    /\ attemptState' = [attemptState EXCEPT ![k] = "timed_out"]
    /\ futureState' = IF k = MAX_RETRIES THEN "rejected" ELSE "unresolved"
    /\ UNCHANGED <<wallClock, managerState, lastHeartbeat, heartbeatInFlight,
                    attemptStart, attemptDeadline, currentAttempt, resultState>>

RetryAttempt ==
    /\ attemptState[currentAttempt] = "timed_out"
    /\ currentAttempt < MAX_RETRIES
    /\ currentAttempt' = currentAttempt + 1
    /\ UNCHANGED <<wallClock, managerState, lastHeartbeat, heartbeatInFlight,
                    attemptState, attemptStart, attemptDeadline,
                    futureState, resultState>>

RetryLostAttempt ==
    /\ attemptState[currentAttempt] = "lost"
    /\ currentAttempt < MAX_RETRIES
    /\ currentAttempt' = currentAttempt + 1
    /\ UNCHANGED <<wallClock, managerState, lastHeartbeat,
                    heartbeatInFlight, attemptState, attemptStart,
                    attemptDeadline, futureState, resultState>>

RejectLostAttempt ==
    /\ attemptState[currentAttempt] = "lost"
    /\ currentAttempt = MAX_RETRIES
    /\ futureState = "unresolved"
    /\ futureState' = "rejected"
    /\ UNCHANGED <<wallClock, managerState, lastHeartbeat,
                    heartbeatInFlight, attemptState, attemptStart,
                    attemptDeadline, currentAttempt, resultState>>

SendResult(k) ==
    /\ attemptState[k] \in {"completed", "timed_out", "lost"}
    /\ resultState[k] = "none"
    /\ resultState' = [resultState EXCEPT ![k] = "sent"]
    /\ UNCHANGED <<wallClock, managerState, lastHeartbeat, heartbeatInFlight,
                    attemptState, attemptStart, attemptDeadline,
                    currentAttempt, futureState>>

DeliverResult(k) ==
    /\ resultState[k] = "sent"
    /\ resultState' = [resultState EXCEPT ![k] =
          IF k = currentAttempt /\ attemptState[k] = "completed"
          THEN "delivered" ELSE "stale"]
    /\ UNCHANGED <<wallClock, managerState, lastHeartbeat, heartbeatInFlight,
                    attemptState, attemptStart, attemptDeadline,
                    currentAttempt, futureState>>

Next ==
    \/ Tick
    \/ \E w \in WORKERS : SendHeartbeat(w) \/ DeliverHeartbeat(w) \/ DropHeartbeat(w)
    \/ ExpireManager
    \/ RecoverManager
    \/ \E k \in AttemptIds : StartAttempt(k) \/ CompleteAttempt(k)
    \/ \E k \in AttemptIds : TimeoutAttempt(k)
    \/ RetryAttempt
    \/ RetryLostAttempt
    \/ RejectLostAttempt
    \/ \E k \in AttemptIds : SendResult(k) \/ DeliverResult(k)
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ wallClock \in 0..MAX_TIME
    /\ managerState \in ManagerStates
    /\ lastHeartbeat \in [WORKERS -> 0..MAX_TIME]
    /\ heartbeatInFlight \in [WORKERS -> BOOLEAN]
    /\ attemptState \in [AttemptIds -> AttemptStates]
    /\ attemptStart \in [AttemptIds -> (-1)..(MAX_TIME + TASK_TIMEOUT)]
    /\ attemptDeadline \in [AttemptIds -> (-1)..(MAX_TIME + TASK_TIMEOUT)]
    /\ currentAttempt \in AttemptIds
    /\ futureState \in FutureStates
    /\ resultState \in [AttemptIds -> ResultStates]

ClockSafety ==
    /\ \A w \in WORKERS : lastHeartbeat[w] <= wallClock
    /\ \A k \in AttemptIds :
          attemptState[k] = "running" =>
             /\ attemptStart[k] <= wallClock
             /\ attemptDeadline[k] = attemptStart[k] + TASK_TIMEOUT

HeartbeatExpirySafety ==
    managerState = "expired"
    => \E w \in WORKERS : wallClock - lastHeartbeat[w] >= HEARTBEAT_TIMEOUT

TimeoutSafety ==
    \A k \in AttemptIds :
        attemptState[k] = "timed_out" => wallClock >= attemptDeadline[k]

ResultSafety ==
    /\ \A k \in AttemptIds :
          resultState[k] = "delivered" =>
             /\ k = currentAttempt
             /\ attemptState[k] = "completed"
    /\ \A k \in AttemptIds :
          resultState[k] = "stale" =>
             k # currentAttempt \/ attemptState[k] # "completed"

FutureSafety ==
    /\ futureState = "resolved" => attemptState[currentAttempt] = "completed"
    /\ futureState = "rejected" =>
          attemptState[currentAttempt] \in {"timed_out", "lost"}

=============================================================================
