--------------------------- MODULE ParslScaleInRetryMonitoring ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Busy worker scale-in, retry, and monitoring.
 *
 * One active block hosts one running task.  Forced scale-in can cancel that
 * block while its result is still in flight.  The current branch accepts the
 * late completion as success; the fixed branch protects busy capacity and
 * treats any late completion as stale.
 ***************************************************************************)

CONSTANT USE_FIXED

BlockStates == {"active", "cancelled"}
TaskStates == {"queued", "running", "lost", "retry_wait", "done"}
MonitorStates == {"none", "running", "retrying", "succeeded"}
LateStates == {"none", "accepted", "stale"}

VARIABLES block, idleWorkers, task, monitor, lateResult, lostSeen
vars == <<block, idleWorkers, task, monitor, lateResult, lostSeen>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ block = "active"
    /\ idleWorkers = 0
    /\ task = "queued"
    /\ monitor = "none"
    /\ lateResult = "none"
    /\ lostSeen = FALSE

Dispatch ==
    /\ task = "queued"
    /\ block = "active"
    /\ idleWorkers = 0
    /\ task' = "running"
    /\ monitor' = "running"
    /\ UNCHANGED <<block, idleWorkers, lateResult, lostSeen>>

ScaleIn ==
    /\ block = "active"
    /\ IF USE_FIXED /\ task = "running"
       THEN /\ block' = "active"
            /\ UNCHANGED task
       ELSE /\ block' = "cancelled"
            /\ task' = IF task = "running" THEN "lost" ELSE task
    /\ lostSeen' = IF ~USE_FIXED /\ task = "running" THEN TRUE ELSE lostSeen
    /\ UNCHANGED <<idleWorkers, monitor, lateResult>>

WorkerRecovery ==
    /\ block = "cancelled"
    /\ block' = "active"
    /\ task' = IF task = "lost" THEN "retry_wait" ELSE task
    /\ monitor' = IF task = "lost" THEN "retrying" ELSE monitor
    /\ UNCHANGED <<idleWorkers, lateResult, lostSeen>>

Retry ==
    /\ task = "retry_wait"
    /\ task' = "queued"
    /\ UNCHANGED <<block, idleWorkers, monitor, lateResult, lostSeen>>

LateComplete ==
    /\ task = "lost"
    /\ IF USE_FIXED
       THEN /\ lateResult' = "stale"
            /\ UNCHANGED task
       ELSE /\ task' = "done"
            /\ monitor' = "succeeded"
            /\ lateResult' = "accepted"
    /\ UNCHANGED <<block, idleWorkers, lostSeen>>

CompleteRetry ==
    /\ task = "running"
    /\ block = "active"
    /\ task' = "done"
    /\ monitor' = "succeeded"
    /\ UNCHANGED <<block, idleWorkers, lateResult, lostSeen>>

Next ==
    \/ Dispatch
    \/ ScaleIn
    \/ WorkerRecovery
    \/ Retry
    \/ LateComplete
    \/ CompleteRetry
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ block \in BlockStates
    /\ idleWorkers \in Nat
    /\ task \in TaskStates
    /\ monitor \in MonitorStates
    /\ lateResult \in LateStates
    /\ lostSeen \in BOOLEAN

BusyScaleInSafety ==
    task = "running" => block = "active"

LostTaskSafety ==
    lostSeen => monitor # "succeeded"

LateResultSafety ==
    task = "lost" => lateResult \in {"none", "stale"}

TerminalMonitoring ==
    monitor = "succeeded" => task = "done"

=============================================================================
