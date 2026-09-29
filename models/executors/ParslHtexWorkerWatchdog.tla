--------------------------- MODULE ParslHtexWorkerWatchdog ---------------------------
EXTENDS Naturals

(***************************************************************************
 * HTEX worker watchdog and logical task recovery.
 *
 * A worker is a physical execution resource; the task belongs to a logical
 * attempt tracked by the manager.  When a busy worker dies, the watchdog
 * emits a WorkerLost result for that task before replacing the worker.  An
 * idle worker can be replaced without producing a task result.
 ***************************************************************************)

CONSTANT BUSY_AT_START

WorkerStates == {"alive", "dead", "restarted"}
TaskStates == {"idle", "running", "failed"}
ResultStates == {"none", "queued", "delivered"}

VARIABLES workerState, taskState, resultState, watchdogCycles
vars == <<workerState, taskState, resultState, watchdogCycles>>

Init ==
    /\ BUSY_AT_START \in BOOLEAN
    /\ workerState = "alive"
    /\ taskState = IF BUSY_AT_START THEN "running" ELSE "idle"
    /\ resultState = "none"
    /\ watchdogCycles = 0

WorkerDies ==
    /\ workerState = "alive"
    /\ workerState' = "dead"
    /\ UNCHANGED <<taskState, resultState, watchdogCycles>>

WatchdogRecovers ==
    /\ workerState = "dead"
    /\ workerState' = "restarted"
    /\ taskState' = IF BUSY_AT_START THEN "failed" ELSE taskState
    /\ resultState' = IF BUSY_AT_START THEN "queued" ELSE resultState
    /\ watchdogCycles' = watchdogCycles + 1

DeliverWorkerLost ==
    /\ workerState = "restarted"
    /\ BUSY_AT_START
    /\ taskState = "failed"
    /\ resultState = "queued"
    /\ resultState' = "delivered"
    /\ UNCHANGED <<workerState, taskState, watchdogCycles>>

Next ==
    \/ WorkerDies
    \/ WatchdogRecovers
    \/ DeliverWorkerLost
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ BUSY_AT_START \in BOOLEAN
    /\ workerState \in WorkerStates
    /\ taskState \in TaskStates
    /\ resultState \in ResultStates
    /\ watchdogCycles \in Nat

RecoverySafety ==
    workerState = "restarted" =>
        /\ watchdogCycles = 1
        /\ IF BUSY_AT_START
              THEN taskState = "failed" /\ resultState \in {"queued", "delivered"}
              ELSE taskState = "idle" /\ resultState = "none"

WorkerLostResultSafety ==
    resultState = "delivered" =>
        /\ BUSY_AT_START
        /\ taskState = "failed"
        /\ workerState = "restarted"

=============================================================================
