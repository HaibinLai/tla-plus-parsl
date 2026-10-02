--------------------------- MODULE ParslHtexLifecycle ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Compact composition model for the HTEX executor/worker path.
 *
 * logicalAttempt identifies the logical task generation; inflightAttempt and
 * resultAttempt identify physical execution/result traffic.  This is enough
 * to connect task admission, worker failure/retry, late results, manager
 * failure, and shutdown without modeling the full ZMQ frame grammar.
 ***************************************************************************)

CONSTANT USE_FIXED

Phases == {"new", "queued", "running", "retrying", "done", "failed", "cancelled"}
ExecutorStates == {"running", "stopping", "stopped"}

VARIABLES phase, logicalAttempt, inflightAttempt, resultPending, resultAttempt,
          managerAlive, workerAlive, executorState
vars == <<phase, logicalAttempt, inflightAttempt, resultPending, resultAttempt,
          managerAlive, workerAlive, executorState>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ phase = "new"
    /\ logicalAttempt = 0
    /\ inflightAttempt = 0
    /\ resultPending = FALSE
    /\ resultAttempt = 0
    /\ managerAlive = TRUE
    /\ workerAlive = TRUE
    /\ executorState = "running"

Submit ==
    /\ phase \in {"new", "retrying"}
    /\ managerAlive
    /\ phase' = "queued"
    /\ UNCHANGED <<logicalAttempt, inflightAttempt, resultPending, resultAttempt,
                    managerAlive, workerAlive, executorState>>

Dispatch ==
    /\ phase = "queued"
    /\ workerAlive
    /\ phase' = "running"
    /\ inflightAttempt' = logicalAttempt
    /\ UNCHANGED <<logicalAttempt, resultPending, resultAttempt,
                    managerAlive, workerAlive, executorState>>

WorkerFails ==
    /\ phase = "running"
    /\ workerAlive
    /\ IF logicalAttempt = 0 THEN
           /\ phase' = "retrying"
           /\ logicalAttempt' = 1
           /\ resultPending' = IF USE_FIXED THEN FALSE ELSE TRUE
           /\ resultAttempt' = 0
       ELSE
           /\ phase' = "failed"
           /\ UNCHANGED <<logicalAttempt, resultPending, resultAttempt>>
    /\ workerAlive' = FALSE
    /\ UNCHANGED <<inflightAttempt, managerAlive, executorState>>

WorkerRestarts ==
    /\ ~workerAlive
    /\ phase = "retrying"
    /\ workerAlive' = TRUE
    /\ UNCHANGED <<phase, logicalAttempt, inflightAttempt, resultPending,
                    resultAttempt, managerAlive, executorState>>

WorkerCompletes ==
    /\ phase = "running"
    /\ workerAlive
    /\ resultPending' = TRUE
    /\ resultAttempt' = inflightAttempt
    /\ UNCHANGED <<phase, logicalAttempt, inflightAttempt,
                    managerAlive, workerAlive, executorState>>

DeliverResult ==
    /\ resultPending
    /\ IF resultAttempt = logicalAttempt THEN
           /\ phase' = "done"
           /\ resultPending' = FALSE
       ELSE IF USE_FIXED THEN
           /\ phase' = phase
           /\ resultPending' = FALSE
       ELSE
           /\ phase' = "done"
           /\ resultPending' = FALSE
    /\ UNCHANGED <<logicalAttempt, inflightAttempt, resultAttempt,
                    managerAlive, workerAlive, executorState>>

DeliverStaleResult ==
    /\ resultPending
    /\ resultAttempt # logicalAttempt
    /\ IF USE_FIXED THEN
           /\ phase' = phase
           /\ resultPending' = FALSE
       ELSE
           /\ phase' = "done"
           /\ resultPending' = FALSE
    /\ UNCHANGED <<logicalAttempt, inflightAttempt, resultAttempt,
                    managerAlive, workerAlive, executorState>>

ManagerFails ==
    /\ managerAlive
    /\ managerAlive' = FALSE
    /\ phase' = IF phase \in {"done", "failed", "cancelled"} THEN phase ELSE "failed"
    /\ resultPending' = FALSE
    /\ UNCHANGED <<logicalAttempt, inflightAttempt, resultAttempt,
                    workerAlive, executorState>>

RequestShutdown ==
    /\ executorState = "running"
    /\ executorState' = "stopping"
    /\ UNCHANGED <<phase, logicalAttempt, inflightAttempt, resultPending,
                    resultAttempt, managerAlive, workerAlive>>

FinishShutdown ==
    /\ executorState = "stopping"
    /\ executorState' = "stopped"
    /\ phase' = IF phase \in {"done", "failed", "cancelled"} THEN phase ELSE "failed"
    /\ resultPending' = FALSE
    /\ UNCHANGED <<logicalAttempt, inflightAttempt, resultAttempt,
                    managerAlive, workerAlive>>

Next ==
    \/ Submit
    \/ Dispatch
    \/ WorkerFails
    \/ WorkerRestarts
    \/ WorkerCompletes
    \/ DeliverResult
    \/ DeliverStaleResult
    \/ ManagerFails
    \/ RequestShutdown
    \/ FinishShutdown
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ phase \in Phases
    /\ logicalAttempt \in 0..1
    /\ inflightAttempt \in 0..1
    /\ resultPending \in BOOLEAN
    /\ resultAttempt \in 0..1
    /\ managerAlive \in BOOLEAN
    /\ workerAlive \in BOOLEAN
    /\ executorState \in ExecutorStates

RetryBound == logicalAttempt \in 0..1
StaleResultSafety == resultPending /\ resultAttempt # logicalAttempt => USE_FIXED
TerminalStability == phase = "done" => ~resultPending
ShutdownTerminal == executorState = "stopped" => phase \in {"done", "failed", "cancelled"}

=============================================================================
