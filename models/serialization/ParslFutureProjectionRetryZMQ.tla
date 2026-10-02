--------------------------- MODULE ParslFutureProjectionRetryZMQ ---------------------------
EXTENDS Naturals, Integers

(***************************************************************************
 * Projection/retry result delivery through a serialized multipart envelope.
 *
 * A logical source task has physical attempts.  Each result frame carries
 * the logical task's attempt identity outside the serialized payload.  The
 * projection may run only after the current attempt's valid frame is
 * accepted; an old frame is consumed as stale and cannot resolve the source.
 ***************************************************************************)

AttemptStates == {"absent", "running", "failed", "succeeded", "stale"}
SourceStates == {"pending", "running", "retry_wait", "succeeded"}
WireStates == {"none", "queued", "consumed", "stale"}
ProjectionStates == {"blocked", "running", "succeeded"}

VARIABLES currentAttempt, sourceState, attemptState, wireState,
          payloadVersion, acceptedAttempt, projectionState
vars == <<currentAttempt, sourceState, attemptState, wireState,
           payloadVersion, acceptedAttempt, projectionState>>

Init ==
    /\ currentAttempt = 0
    /\ sourceState = "pending"
    /\ attemptState = [k \in 0..1 |-> "absent"]
    /\ wireState = [k \in 0..1 |-> "none"]
    /\ payloadVersion = [k \in 0..1 |-> -1]
    /\ acceptedAttempt = -1
    /\ projectionState = "blocked"

StartAttempt ==
    /\ sourceState = "pending"
    /\ attemptState[currentAttempt] = "absent"
    /\ sourceState' = "running"
    /\ attemptState' = [attemptState EXCEPT ![currentAttempt] = "running"]
    /\ UNCHANGED <<currentAttempt, wireState, payloadVersion, acceptedAttempt, projectionState>>

FailAttempt ==
    /\ sourceState = "running"
    /\ currentAttempt = 0
    /\ attemptState[0] = "running"
    /\ sourceState' = "retry_wait"
    /\ attemptState' = [attemptState EXCEPT ![0] = "failed"]
    /\ UNCHANGED <<currentAttempt, wireState, payloadVersion, acceptedAttempt, projectionState>>

Retry ==
    /\ sourceState = "retry_wait"
    /\ currentAttempt' = 1
    /\ sourceState' = "pending"
    /\ UNCHANGED <<attemptState, wireState, payloadVersion, acceptedAttempt, projectionState>>

SerializeCurrentResult ==
    /\ sourceState = "running"
    /\ currentAttempt = 1
    /\ attemptState[1] = "running"
    /\ wireState' = [wireState EXCEPT ![1] = "queued"]
    /\ payloadVersion' = [payloadVersion EXCEPT ![1] = 1]
    /\ attemptState' = [attemptState EXCEPT ![1] = "succeeded"]
    /\ UNCHANGED <<currentAttempt, sourceState, acceptedAttempt, projectionState>>

SerializeLateOldResult ==
    /\ currentAttempt = 1
    /\ attemptState[0] = "failed"
    /\ wireState[0] = "none"
    /\ wireState' = [wireState EXCEPT ![0] = "queued"]
    /\ payloadVersion' = [payloadVersion EXCEPT ![0] = 0]
    /\ UNCHANGED <<currentAttempt, sourceState, attemptState, acceptedAttempt, projectionState>>

DeliverResult(k) ==
    /\ k \in 0..1
    /\ wireState[k] = "queued"
    /\ wireState' = [wireState EXCEPT ![k] = IF k = currentAttempt THEN "consumed" ELSE "stale"]
    /\ IF k = currentAttempt /\ payloadVersion[k] = currentAttempt
       THEN /\ sourceState' = "succeeded"
            /\ acceptedAttempt' = k
            /\ attemptState' = [attemptState EXCEPT ![k] = "succeeded"]
       ELSE /\ sourceState' = sourceState
            /\ acceptedAttempt' = acceptedAttempt
            /\ attemptState' = [attemptState EXCEPT ![k] = "stale"]
    /\ UNCHANGED <<currentAttempt, payloadVersion, projectionState>>

RunProjection ==
    /\ projectionState = "blocked"
    /\ sourceState = "succeeded"
    /\ acceptedAttempt = currentAttempt
    /\ projectionState' = "running"
    /\ UNCHANGED <<currentAttempt, sourceState, attemptState, wireState, payloadVersion, acceptedAttempt>>

FinishProjection ==
    /\ projectionState = "running"
    /\ projectionState' = "succeeded"
    /\ UNCHANGED <<currentAttempt, sourceState, attemptState, wireState, payloadVersion, acceptedAttempt>>

Next ==
    \/ StartAttempt
    \/ FailAttempt
    \/ Retry
    \/ SerializeCurrentResult
    \/ SerializeLateOldResult
    \/ \E k \in 0..1 : DeliverResult(k)
    \/ RunProjection
    \/ FinishProjection
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ currentAttempt \in 0..1
    /\ sourceState \in SourceStates
    /\ attemptState \in [0..1 -> AttemptStates]
    /\ wireState \in [0..1 -> WireStates]
    /\ payloadVersion \in [0..1 -> -1..1]
    /\ acceptedAttempt \in {-1, 0, 1}
    /\ projectionState \in ProjectionStates

AttemptCorrelationSafety ==
    \A k \in 0..1 : wireState[k] = "consumed" => k = currentAttempt

PayloadSnapshotSafety ==
    \A k \in 0..1 : wireState[k] \in {"queued", "consumed", "stale"}
        => payloadVersion[k] = k

StaleFrameIsolation ==
    wireState[0] = "stale" => acceptedAttempt # 0

ProjectionResultSafety ==
    projectionState \in {"running", "succeeded"} =>
        /\ sourceState = "succeeded"
        /\ acceptedAttempt = currentAttempt

=============================================================================
