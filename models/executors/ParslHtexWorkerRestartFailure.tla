--------------------------- MODULE ParslHtexWorkerRestartFailure ---------------------------
EXTENDS Naturals

(***************************************************************************
 * HTEX Manager.worker_watchdog detects dead workers, emits a WorkerLost
 * result for busy work, and then calls _start_worker.  In the current source
 * an exception from _start_worker escapes the watchdog loop.  USE_FIXED makes
 * that failure an explicit executor-bad terminal state instead.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES workerState, watchdogState, executorState, taskState,
          lossEnvelope, restartAttempted
vars == <<workerState, watchdogState, executorState, taskState,
          lossEnvelope, restartAttempted>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ workerState = "alive"
    /\ watchdogState = "running"
    /\ executorState = "healthy"
    /\ taskState = "pending"
    /\ lossEnvelope = FALSE
    /\ restartAttempted = FALSE

DetectDeadWorker ==
    /\ workerState = "alive"
    /\ workerState' = "dead"
    /\ UNCHANGED <<watchdogState, executorState, taskState,
                    lossEnvelope, restartAttempted>>

EmitWorkerLost ==
    /\ workerState = "dead"
    /\ ~lossEnvelope
    /\ taskState' = "terminal"
    /\ lossEnvelope' = TRUE
    /\ UNCHANGED <<workerState, watchdogState, executorState, restartAttempted>>

RestartWorker ==
    /\ workerState = "dead"
    /\ lossEnvelope
    /\ workerState' = "restarted"
    /\ restartAttempted' = TRUE
    /\ UNCHANGED <<watchdogState, executorState, taskState,
                    lossEnvelope>>

RestartFailure ==
    /\ workerState = "dead"
    /\ lossEnvelope
    /\ workerState' = "restart_failed"
    /\ restartAttempted' = TRUE
    /\ IF USE_FIXED
          THEN /\ watchdogState' = "failed"
               /\ executorState' = "bad"
          ELSE /\ watchdogState' = "stopped"
               /\ executorState' = "healthy"
    /\ UNCHANGED <<taskState, lossEnvelope>>

Next ==
    \/ DetectDeadWorker
    \/ EmitWorkerLost
    \/ RestartWorker
    \/ RestartFailure
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ workerState \in {"alive", "dead", "restarted", "restart_failed"}
    /\ watchdogState \in {"running", "stopped", "failed"}
    /\ executorState \in {"healthy", "bad"}
    /\ taskState \in {"pending", "terminal"}
    /\ lossEnvelope \in BOOLEAN
    /\ restartAttempted \in BOOLEAN

RestartFailureSafety ==
    workerState = "restart_failed" => executorState = "bad"

LossOutcomeSafety ==
    lossEnvelope => taskState = "terminal"

WatchdogFailureVisibility ==
    watchdogState = "failed" => executorState = "bad"

=============================================================================
