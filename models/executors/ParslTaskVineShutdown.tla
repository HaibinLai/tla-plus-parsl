--------------------------- MODULE ParslTaskVineShutdown ---------------------------
EXTENDS Naturals

(***************************************************************************
 * TaskVineExecutor collector shutdown/finalization.
 *
 * The TaskVine collector exits when its stop event is set and its finally
 * block marks every task still waiting in the task map with
 * TaskVineManagerFailure before the collector terminates.
 ***************************************************************************)

States == {"running", "stopping", "stopped"}
FutureStates == {"pending", "succeeded", "failed"}

VARIABLES executorState, collectorState, futureState
vars == <<executorState, collectorState, futureState>>

Init ==
    /\ executorState = "running"
    /\ collectorState = "active"
    /\ futureState = "pending"

RequestShutdown ==
    /\ executorState = "running"
    /\ executorState' = "stopping"
    /\ UNCHANGED <<collectorState, futureState>>

CollectorReceivesResult ==
    /\ collectorState = "active"
    /\ futureState = "pending"
    /\ futureState' = "succeeded"
    /\ UNCHANGED <<executorState, collectorState>>

CollectorExits ==
    /\ collectorState = "active"
    /\ collectorState' = "exited"
    /\ futureState' = IF futureState = "pending" THEN "failed" ELSE futureState
    /\ UNCHANGED executorState

FinishShutdown ==
    /\ executorState = "stopping"
    /\ collectorState = "exited"
    /\ executorState' = "stopped"
    /\ UNCHANGED <<collectorState, futureState>>

Next ==
    \/ RequestShutdown
    \/ CollectorReceivesResult
    \/ CollectorExits
    \/ FinishShutdown
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ executorState \in States
    /\ collectorState \in {"active", "exited"}
    /\ futureState \in FutureStates

ShutdownFutureSafety ==
    executorState = "stopped" => futureState \in {"succeeded", "failed"}

CollectorExitSafety ==
    collectorState = "exited" => futureState # "pending"

=============================================================================
