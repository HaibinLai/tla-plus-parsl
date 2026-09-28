--------------------------- MODULE ParslFutureProjection ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Bounded model of AppFuture.__getitem__ and AppFuture.__getattr__.
 *
 * A projection creates a new logical task on the internal executor without
 * synchronously waiting for its source Future.  The projection can execute
 * only after the source succeeds; source failure or an invalid key becomes a
 * failure of the projection task.
 ***************************************************************************)

CONSTANT KEY_VALID

SourceStates == {"pending", "succeeded", "failed"}
ProjectionStates == {"not-created", "blocked", "running", "succeeded", "failed"}

VARIABLES sourceState, projectionState, projectionValue
vars == <<sourceState, projectionState, projectionValue>>

Init ==
    /\ KEY_VALID \in BOOLEAN
    /\ sourceState = "pending"
    /\ projectionState = "not-created"
    /\ projectionValue = "none"

CreateProjection ==
    /\ projectionState = "not-created"
    /\ projectionState' = "blocked"
    /\ UNCHANGED <<sourceState, projectionValue>>

CompleteSource ==
    /\ sourceState = "pending"
    /\ sourceState' = "succeeded"
    /\ UNCHANGED <<projectionState, projectionValue>>

FailSource ==
    /\ sourceState = "pending"
    /\ sourceState' = "failed"
    /\ UNCHANGED <<projectionState, projectionValue>>

RunProjection ==
    /\ projectionState = "blocked"
    /\ sourceState = "succeeded"
    /\ projectionState' = "running"
    /\ UNCHANGED <<sourceState, projectionValue>>

PropagateSourceFailure ==
    /\ projectionState = "blocked"
    /\ sourceState = "failed"
    /\ projectionState' = "failed"
    /\ projectionValue' = "dependency-error"
    /\ UNCHANGED sourceState

FinishProjection ==
    /\ projectionState = "running"
    /\ IF sourceState = "failed" THEN
           /\ projectionState' = "failed"
           /\ projectionValue' = "dependency-error"
       ELSE IF KEY_VALID THEN
           /\ projectionState' = "succeeded"
           /\ projectionValue' = "projected-value"
       ELSE
           /\ projectionState' = "failed"
           /\ projectionValue' = "key-error"
    /\ UNCHANGED sourceState

Next ==
    \/ CreateProjection
    \/ CompleteSource
    \/ FailSource
    \/ RunProjection
    \/ PropagateSourceFailure
    \/ FinishProjection
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ sourceState \in SourceStates
    /\ projectionState \in ProjectionStates
    /\ projectionValue \in {"none", "projected-value", "dependency-error", "key-error"}

ProjectionDependencySafety ==
    /\ projectionState \in {"running", "succeeded"} => sourceState = "succeeded"
    /\ projectionState = "blocked" => sourceState \in SourceStates

ProjectionResultSafety ==
    /\ projectionState = "succeeded" => projectionValue = "projected-value"
    /\ projectionValue = "dependency-error" => sourceState = "failed"
    /\ projectionValue = "key-error" => ~KEY_VALID

=============================================================================
