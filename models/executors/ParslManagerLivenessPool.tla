--------------------------- MODULE ParslManagerLivenessPool ---------------------------
EXTENDS Naturals, Integers

(***************************************************************************
 * A bounded two-manager liveness/admission model.
 *
 * Heartbeats make manager M1 expire.  A logical task may be retried after an
 * attempt on that manager is lost.  The current branch admits a new attempt
 * to the expired manager and accepts its late result; the fixed branch checks
 * liveness at admission and classifies the old result as stale.
 ***************************************************************************)

CONSTANTS MAX_TIME, MAX_RETRIES, USE_FIXED

Managers == {"M1", "M2"}
ManagerStates == {"up", "expired"}
TaskStates == {"pending", "running", "lost", "succeeded"}

VARIABLES now, managerState, lastHeartbeat, task, assigned, attempt,
          lateResult, lateAccepted

vars == <<now, managerState, lastHeartbeat, task, assigned, attempt,
           lateResult, lateAccepted>>

Init ==
    /\ MAX_TIME >= 3
    /\ MAX_RETRIES >= 1
    /\ USE_FIXED \in BOOLEAN
    /\ now = 0
    /\ managerState = [m \in Managers |-> "up"]
    /\ lastHeartbeat = [m \in Managers |-> 0]
    /\ task = "pending"
    /\ assigned = "none"
    /\ attempt = 0
    /\ lateResult = "none"
    /\ lateAccepted = FALSE

Tick ==
    /\ now < MAX_TIME
    /\ now' = now + 1
    /\ UNCHANGED <<managerState, lastHeartbeat, task, assigned, attempt,
                    lateResult, lateAccepted>>

HeartbeatM2 ==
    /\ managerState["M2"] = "up"
    /\ lastHeartbeat' = [lastHeartbeat EXCEPT !["M2"] = now]
    /\ UNCHANGED <<now, managerState, task, assigned, attempt,
                    lateResult, lateAccepted>>

ExpireM1 ==
    /\ managerState["M1"] = "up"
    /\ now - lastHeartbeat["M1"] >= 2
    /\ managerState' = [managerState EXCEPT !["M1"] = "expired"]
    /\ task' = IF assigned = "M1" /\ task = "running" THEN "lost" ELSE task
    /\ UNCHANGED <<now, lastHeartbeat, assigned, attempt, lateResult,
                    lateAccepted>>

StartOnM1 ==
    /\ task = "pending"
    /\ (IF USE_FIXED THEN managerState["M1"] = "up" ELSE TRUE)
    /\ task' = "running"
    /\ assigned' = "M1"
    /\ UNCHANGED <<now, managerState, lastHeartbeat, attempt, lateResult,
                    lateAccepted>>

StartOnM2 ==
    /\ task = "pending"
    /\ managerState["M2"] = "up"
    /\ task' = "running"
    /\ assigned' = "M2"
    /\ UNCHANGED <<now, managerState, lastHeartbeat, attempt, lateResult,
                    lateAccepted>>

RetryLost ==
    /\ task = "lost"
    /\ attempt < MAX_RETRIES
    /\ task' = "pending"
    /\ attempt' = attempt + 1
    /\ assigned' = "none"
    /\ UNCHANGED <<now, managerState, lastHeartbeat, lateResult, lateAccepted>>

CompleteCurrentAttempt ==
    /\ task = "running"
    /\ managerState[assigned] = "up"
    /\ task' = "succeeded"
    /\ UNCHANGED <<now, managerState, lastHeartbeat, assigned, attempt,
                    lateResult, lateAccepted>>

SendLateResult ==
    /\ task = "lost"
    /\ lateResult = "none"
    /\ lateResult' = "sent"
    /\ UNCHANGED <<now, managerState, lastHeartbeat, task, assigned, attempt,
                    lateAccepted>>

DeliverLateResult ==
    /\ lateResult = "sent"
    /\ lateResult' = "delivered"
    /\ IF USE_FIXED
       THEN /\ lateAccepted' = FALSE
            /\ UNCHANGED task
       ELSE /\ lateAccepted' = TRUE
            /\ task' = "succeeded"
    /\ UNCHANGED <<now, managerState, lastHeartbeat, assigned, attempt>>

Next ==
    \/ Tick
    \/ HeartbeatM2
    \/ ExpireM1
    \/ StartOnM1
    \/ StartOnM2
    \/ RetryLost
    \/ CompleteCurrentAttempt
    \/ SendLateResult
    \/ DeliverLateResult
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ now \in 0..MAX_TIME
    /\ managerState \in [Managers -> ManagerStates]
    /\ lastHeartbeat \in [Managers -> 0..MAX_TIME]
    /\ task \in TaskStates
    /\ assigned \in {"none"} \cup Managers
    /\ attempt \in 0..MAX_RETRIES
    /\ lateResult \in {"none", "sent", "delivered"}
    /\ lateAccepted \in BOOLEAN

LiveManagerAdmission ==
    task = "running" => managerState[assigned] = "up"

NoLateResultAcceptance ==
    ~lateAccepted

RetryBound == attempt <= MAX_RETRIES

TerminalStability ==
    task = "succeeded" => ~lateAccepted

=============================================================================
