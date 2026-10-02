--------------------------- MODULE ParslFutureProjectionRetry ---------------------------
EXTENDS Naturals, Integers

(***************************************************************************
 * AppFuture projection over a retried logical task.
 *
 * __getitem__ and __getattr__ create an internal projection task.  The
 * projection must wait for the logical AppFuture, not for an arbitrary
 * physical execution attempt.  A failed attempt may later deliver a stale
 * result after a retry has become current; that result must not resolve the
 * source Future or release the projection.
 ***************************************************************************)

AttemptStates == {"absent", "running", "failed", "succeeded", "stale"}
SourceStates == {"pending", "running", "retry_wait", "succeeded", "failed"}
ProjectionStates == {"not-created", "blocked", "running", "succeeded", "failed"}

VARIABLES currentAttempt, sourceState, attemptState, projectionState,
          acceptedAttempt
vars == <<currentAttempt, sourceState, attemptState, projectionState,
           acceptedAttempt>>

Init ==
    /\ currentAttempt = 0
    /\ sourceState = "pending"
    /\ attemptState = [k \in 0..1 |-> "absent"]
    /\ projectionState = "not-created"
    /\ acceptedAttempt = -1

CreateProjection ==
    /\ projectionState = "not-created"
    /\ projectionState' = "blocked"
    /\ UNCHANGED <<currentAttempt, sourceState, attemptState, acceptedAttempt>>

StartAttempt ==
    /\ sourceState = "pending"
    /\ attemptState[currentAttempt] = "absent"
    /\ sourceState' = "running"
    /\ attemptState' = [attemptState EXCEPT ![currentAttempt] = "running"]
    /\ UNCHANGED <<currentAttempt, projectionState, acceptedAttempt>>

FailAttempt ==
    /\ sourceState = "running"
    /\ attemptState[currentAttempt] = "running"
    /\ attemptState' = [attemptState EXCEPT ![currentAttempt] = "failed"]
    /\ sourceState' = IF currentAttempt = 0 THEN "retry_wait" ELSE "failed"
    /\ UNCHANGED <<currentAttempt, projectionState, acceptedAttempt>>

Retry ==
    /\ sourceState = "retry_wait"
    /\ currentAttempt = 0
    /\ currentAttempt' = 1
    /\ sourceState' = "pending"
    /\ UNCHANGED <<attemptState, projectionState, acceptedAttempt>>

CompleteCurrentAttempt ==
    /\ sourceState = "running"
    /\ attemptState[currentAttempt] = "running"
    /\ attemptState' = [attemptState EXCEPT ![currentAttempt] = "succeeded"]
    /\ UNCHANGED <<currentAttempt, sourceState, projectionState, acceptedAttempt>>

AcceptCurrentResult ==
    /\ sourceState = "running"
    /\ attemptState[currentAttempt] = "succeeded"
    /\ sourceState' = "succeeded"
    /\ acceptedAttempt' = currentAttempt
    /\ UNCHANGED <<currentAttempt, attemptState, projectionState>>

LateOldResult ==
    /\ currentAttempt = 1
    /\ attemptState[0] = "failed"
    /\ attemptState' = [attemptState EXCEPT ![0] = "stale"]
    /\ UNCHANGED <<currentAttempt, sourceState, projectionState, acceptedAttempt>>

RunProjection ==
    /\ projectionState = "blocked"
    /\ sourceState = "succeeded"
    /\ acceptedAttempt = currentAttempt
    /\ projectionState' = "running"
    /\ UNCHANGED <<currentAttempt, sourceState, attemptState, acceptedAttempt>>

FinishProjection ==
    /\ projectionState = "running"
    /\ sourceState = "succeeded"
    /\ projectionState' = "succeeded"
    /\ UNCHANGED <<currentAttempt, sourceState, attemptState, acceptedAttempt>>

Next ==
    \/ CreateProjection
    \/ StartAttempt
    \/ FailAttempt
    \/ Retry
    \/ CompleteCurrentAttempt
    \/ AcceptCurrentResult
    \/ LateOldResult
    \/ RunProjection
    \/ FinishProjection
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ currentAttempt \in 0..1
    /\ sourceState \in SourceStates
    /\ attemptState \in [0..1 -> AttemptStates]
    /\ projectionState \in ProjectionStates
    /\ acceptedAttempt \in {-1, 0, 1}

RetryBound == currentAttempt <= 1

ProjectionDependencySafety ==
    projectionState \in {"running", "succeeded"} => sourceState = "succeeded"

ProjectionAttemptSafety ==
    projectionState \in {"running", "succeeded"} => acceptedAttempt = currentAttempt

StaleResultSafety ==
    attemptState[0] = "stale" => acceptedAttempt # 0

TerminalStability ==
    projectionState = "succeeded" => sourceState = "succeeded"

=============================================================================
