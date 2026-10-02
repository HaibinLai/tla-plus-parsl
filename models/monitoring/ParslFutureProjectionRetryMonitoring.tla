--------------------------- MODULE ParslFutureProjectionRetryMonitoring ---------------------------
EXTENDS Naturals, Integers

(***************************************************************************
 * Monitoring projection for a retried AppFuture and its internal projection.
 *
 * The database keeps the highest logical attempt observed for a task.  A
 * late status from attempt 0 must not roll that high-water back after attempt
 * 1 is current, and the projection must not run until the current attempt is
 * terminally successful.
 ***************************************************************************)

AttemptStates == {"absent", "running", "failed", "succeeded", "stale"}
SourceStates == {"pending", "running", "retry_wait", "succeeded"}
ProjectionStates == {"blocked", "running", "succeeded"}
DbStates == {"none", "running", "failed", "done"}

VARIABLES currentAttempt, sourceState, attemptState, projectionState,
          acceptedAttempt, dbTry, dbState
vars == <<currentAttempt, sourceState, attemptState, projectionState,
           acceptedAttempt, dbTry, dbState>>

Init ==
    /\ currentAttempt = 0
    /\ sourceState = "pending"
    /\ attemptState = [k \in 0..1 |-> "absent"]
    /\ projectionState = "blocked"
    /\ acceptedAttempt = -1
    /\ dbTry = -1
    /\ dbState = "none"

StartAttempt ==
    /\ sourceState = "pending"
    /\ attemptState[currentAttempt] = "absent"
    /\ sourceState' = "running"
    /\ attemptState' = [attemptState EXCEPT ![currentAttempt] = "running"]
    /\ dbTry' = currentAttempt
    /\ dbState' = "running"
    /\ UNCHANGED <<currentAttempt, projectionState, acceptedAttempt>>

FailAttempt ==
    /\ sourceState = "running"
    /\ attemptState[currentAttempt] = "running"
    /\ currentAttempt = 0
    /\ sourceState' = "retry_wait"
    /\ attemptState' = [attemptState EXCEPT ![0] = "failed"]
    /\ dbTry' = 0
    /\ dbState' = "failed"
    /\ UNCHANGED <<currentAttempt, projectionState, acceptedAttempt>>

Retry ==
    /\ sourceState = "retry_wait"
    /\ currentAttempt' = 1
    /\ sourceState' = "pending"
    /\ UNCHANGED <<attemptState, projectionState, acceptedAttempt, dbTry, dbState>>

CompleteAttempt ==
    /\ sourceState = "running"
    /\ currentAttempt = 1
    /\ attemptState[1] = "running"
    /\ attemptState' = [attemptState EXCEPT ![1] = "succeeded"]
    /\ sourceState' = "succeeded"
    /\ acceptedAttempt' = 1
    /\ dbTry' = 1
    /\ dbState' = "done"
    /\ UNCHANGED <<currentAttempt, projectionState>>

LateOldStatus ==
    /\ currentAttempt = 1
    /\ dbTry = 1
    /\ attemptState[0] = "failed"
    /\ dbTry' = dbTry
    /\ dbState' = dbState
    /\ attemptState' = [attemptState EXCEPT ![0] = "stale"]
    /\ UNCHANGED <<currentAttempt, sourceState, projectionState, acceptedAttempt>>

RunProjection ==
    /\ projectionState = "blocked"
    /\ sourceState = "succeeded"
    /\ acceptedAttempt = currentAttempt
    /\ dbTry = currentAttempt
    /\ dbState = "done"
    /\ projectionState' = "running"
    /\ UNCHANGED <<currentAttempt, sourceState, attemptState, acceptedAttempt, dbTry, dbState>>

FinishProjection ==
    /\ projectionState = "running"
    /\ projectionState' = "succeeded"
    /\ UNCHANGED <<currentAttempt, sourceState, attemptState, acceptedAttempt, dbTry, dbState>>

Next ==
    \/ StartAttempt
    \/ FailAttempt
    \/ Retry
    \/ CompleteAttempt
    \/ LateOldStatus
    \/ RunProjection
    \/ FinishProjection
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ currentAttempt \in 0..1
    /\ sourceState \in SourceStates
    /\ attemptState \in [0..1 -> AttemptStates]
    /\ projectionState \in ProjectionStates
    /\ acceptedAttempt \in {-1, 1}
    /\ dbTry \in -1..1
    /\ dbState \in DbStates

MonitoringHighWater == dbTry >= acceptedAttempt

CurrentAttemptPublished ==
    sourceState = "succeeded" => dbTry = currentAttempt /\ dbState = "done"

ProjectionMonitoringSafety ==
    projectionState \in {"running", "succeeded"} =>
        /\ sourceState = "succeeded"
        /\ dbTry = currentAttempt
        /\ dbState = "done"

StaleStatusIsolation ==
    attemptState[0] = "stale" => dbTry = 1

=============================================================================
