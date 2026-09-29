--------------------------- MODULE ParslHtexManagerTaskAdmission ---------------------------
EXTENDS Naturals

(***************************************************************************
 * HTEX manager registration, task admission, heartbeat expiry, and retry.
 *
 * DFK submission may queue a task before a manager registers.  Dispatch must
 * wait for a live manager.  If heartbeat expiry loses a running attempt, a
 * retry can be queued while the old result remains in flight.  The current
 * branch admits queued work without a manager and accepts the old result; the
 * fixed branch gates dispatch and rejects stale completion.
 ***************************************************************************)

CONSTANTS MAX_TIME, HEARTBEAT_TIMEOUT, MAX_RETRIES, USE_FIXED

TaskStates == {"queued", "running", "lost", "done"}
ManagerStates == {"absent", "ready", "expired"}
ResultStates == {"none", "stale", "resolved"}

VARIABLES now, manager, lastHeartbeat, task, currentAttempt,
          resultState, future
vars == <<now, manager, lastHeartbeat, task, currentAttempt,
           resultState, future>>

Init ==
    /\ MAX_TIME >= 3
    /\ HEARTBEAT_TIMEOUT > 0
    /\ MAX_RETRIES >= 1
    /\ USE_FIXED \in BOOLEAN
    /\ now = 0
    /\ manager = "absent"
    /\ lastHeartbeat = 0
    /\ task = "queued"
    /\ currentAttempt = 0
    /\ resultState = "none"
    /\ future = "unresolved"

RegisterManager ==
    /\ manager \in {"absent", "expired"}
    /\ manager' = "ready"
    /\ lastHeartbeat' = now
    /\ UNCHANGED <<now, task, currentAttempt, resultState, future>>

Heartbeat ==
    /\ manager = "ready"
    /\ lastHeartbeat' = now
    /\ UNCHANGED <<now, manager, task, currentAttempt, resultState, future>>

Tick ==
    /\ now < MAX_TIME
    /\ now' = now + 1
    /\ UNCHANGED <<manager, lastHeartbeat, task, currentAttempt,
                    resultState, future>>

ExpireManager ==
    /\ manager = "ready"
    /\ now - lastHeartbeat >= HEARTBEAT_TIMEOUT
    /\ manager' = "expired"
    /\ task' = IF task = "running" THEN "lost" ELSE task
    /\ future' = IF task = "running" THEN "unresolved" ELSE future
    /\ UNCHANGED <<now, lastHeartbeat, currentAttempt, resultState>>

Dispatch ==
    /\ task = "queued"
    /\ IF USE_FIXED THEN manager = "ready" ELSE TRUE
    /\ task' = "running"
    /\ UNCHANGED <<now, manager, lastHeartbeat, currentAttempt,
                    resultState, future>>

Complete ==
    /\ task = "running"
    /\ manager = "ready"
    /\ task' = "done"
    /\ future' = "resolved"
    /\ resultState' = "resolved"
    /\ UNCHANGED <<now, manager, lastHeartbeat, currentAttempt>>

Retry ==
    /\ task = "lost"
    /\ currentAttempt < MAX_RETRIES
    /\ currentAttempt' = currentAttempt + 1
    /\ task' = "queued"
    /\ UNCHANGED <<now, manager, lastHeartbeat, resultState, future>>

LateComplete ==
    /\ task = "lost"
    /\ IF USE_FIXED
       THEN /\ resultState' = "stale"
            /\ UNCHANGED <<task, future>>
       ELSE /\ task' = "done"
            /\ future' = "resolved"
            /\ resultState' = "resolved"
    /\ UNCHANGED <<now, manager, lastHeartbeat, currentAttempt>>

Next ==
    \/ RegisterManager
    \/ Heartbeat
    \/ Tick
    \/ ExpireManager
    \/ Dispatch
    \/ Complete
    \/ Retry
    \/ LateComplete
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ now \in 0..MAX_TIME
    /\ manager \in ManagerStates
    /\ lastHeartbeat \in 0..MAX_TIME
    /\ task \in TaskStates
    /\ currentAttempt \in 0..MAX_RETRIES
    /\ resultState \in ResultStates
    /\ future \in {"unresolved", "resolved"}

AdmissionSafety ==
    task = "running" => manager = "ready"

HeartbeatSafety ==
    manager = "expired" => now - lastHeartbeat >= HEARTBEAT_TIMEOUT

RetryBound == currentAttempt <= MAX_RETRIES

StaleResultSafety ==
    task = "lost" => resultState \in {"none", "stale"}

FutureSafety ==
    future = "resolved" => task = "done"

=============================================================================
