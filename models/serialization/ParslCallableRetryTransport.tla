--------------------------- MODULE ParslCallableRetryTransport ---------------------------
EXTENDS Naturals, Integers

(***************************************************************************
 * Callable-content snapshots across retry and task/result transport.
 *
 * Each physical attempt serializes the current callable/object version into
 * immutable task bytes.  A failed attempt may later produce a result after a
 * retry has captured a newer version.  Result correlation must therefore use
 * both the logical task and attempt number; an old result is stale even when
 * its payload is otherwise valid.
 ***************************************************************************)

CONSTANTS MAX_VERSION, MAX_RETRIES, USE_FIXED

AttemptIds == 0..MAX_RETRIES
AttemptStates == {"absent", "serialized", "running", "failed", "succeeded", "stale"}
WireStates == {"none", "queued", "consumed"}
TaskStates == {"pending", "running", "retry_wait", "succeeded", "failed"}

VARIABLES sourceVersion, currentAttempt, task,
          attemptState, capturedVersion, resultWire,
          resultVersion, futureVersion
vars == <<sourceVersion, currentAttempt, task,
          attemptState, capturedVersion, resultWire,
          resultVersion, futureVersion>>

Init ==
    /\ MAX_VERSION >= 1
    /\ MAX_RETRIES = 1
    /\ USE_FIXED \in BOOLEAN
    /\ sourceVersion = 0
    /\ currentAttempt = 0
    /\ task = "pending"
    /\ attemptState = [k \in AttemptIds |-> "absent"]
    /\ capturedVersion = [k \in AttemptIds |-> -1]
    /\ resultWire = [k \in AttemptIds |-> "none"]
    /\ resultVersion = [k \in AttemptIds |-> -1]
    /\ futureVersion = -1

SerializeAttempt ==
    /\ task = "pending"
    /\ attemptState[currentAttempt] = "absent"
    /\ capturedVersion' = [capturedVersion EXCEPT ![currentAttempt] = sourceVersion]
    /\ attemptState' = [attemptState EXCEPT ![currentAttempt] = "serialized"]
    /\ task' = "running"
    /\ UNCHANGED <<sourceVersion, currentAttempt, resultWire,
                    resultVersion, futureVersion>>

MutateSource ==
    /\ task = "running"
    /\ sourceVersion < MAX_VERSION
    /\ sourceVersion' = sourceVersion + 1
    /\ UNCHANGED <<currentAttempt, task, attemptState, capturedVersion,
                    resultWire, resultVersion, futureVersion>>

FailAttempt ==
    /\ task = "running"
    /\ attemptState[currentAttempt] = "serialized"
    /\ attemptState' = [attemptState EXCEPT ![currentAttempt] = "failed"]
    /\ task' = IF currentAttempt < MAX_RETRIES THEN "retry_wait" ELSE "failed"
    /\ UNCHANGED <<sourceVersion, currentAttempt, capturedVersion,
                    resultWire, resultVersion, futureVersion>>

Retry ==
    /\ task = "retry_wait"
    /\ currentAttempt < MAX_RETRIES
    /\ currentAttempt' = currentAttempt + 1
    /\ task' = "pending"
    /\ UNCHANGED <<sourceVersion, attemptState, capturedVersion,
                    resultWire, resultVersion, futureVersion>>

CompleteAttempt(k) ==
    /\ k \in AttemptIds
    /\ attemptState[k] = "serialized"
    /\ resultWire' = [resultWire EXCEPT ![k] = "queued"]
    /\ resultVersion' = [resultVersion EXCEPT ![k] = capturedVersion[k]]
    /\ attemptState' = [attemptState EXCEPT ![k] = "succeeded"]
    /\ UNCHANGED <<sourceVersion, currentAttempt, task,
                    capturedVersion, futureVersion>>

LateComplete(k) ==
    /\ k \in AttemptIds
    /\ attemptState[k] = "failed"
    /\ resultWire[k] = "none"
    /\ resultWire' = [resultWire EXCEPT ![k] = "queued"]
    /\ resultVersion' = [resultVersion EXCEPT ![k] = capturedVersion[k]]
    /\ UNCHANGED <<sourceVersion, currentAttempt, task,
                    attemptState, capturedVersion, futureVersion>>

DeliverResult(k) ==
    /\ k \in AttemptIds
    /\ resultWire[k] = "queued"
    /\ resultWire' = [resultWire EXCEPT ![k] = "consumed"]
    /\ IF k = currentAttempt /\ task = "running"
       THEN /\ task' = "succeeded"
            /\ futureVersion' = resultVersion[k]
            /\ attemptState' = attemptState
       ELSE IF USE_FIXED
            THEN /\ task' = task
                 /\ futureVersion' = futureVersion
                 /\ attemptState' = [attemptState EXCEPT ![k] = "stale"]
            ELSE /\ task' = "succeeded"
                 /\ futureVersion' = resultVersion[k]
                 /\ attemptState' = attemptState
    /\ UNCHANGED <<sourceVersion, currentAttempt, capturedVersion, resultVersion>>

Next ==
    \/ SerializeAttempt
    \/ MutateSource
    \/ FailAttempt
    \/ Retry
    \/ \E k \in AttemptIds : CompleteAttempt(k) \/ LateComplete(k) \/ DeliverResult(k)
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ sourceVersion \in 0..MAX_VERSION
    /\ currentAttempt \in AttemptIds
    /\ task \in TaskStates
    /\ attemptState \in [AttemptIds -> AttemptStates]
    /\ capturedVersion \in [AttemptIds -> -1..MAX_VERSION]
    /\ resultWire \in [AttemptIds -> WireStates]
    /\ resultVersion \in [AttemptIds -> -1..MAX_VERSION]
    /\ futureVersion \in -1..MAX_VERSION

RetryBound == currentAttempt <= MAX_RETRIES

SnapshotSafety ==
    \A k \in AttemptIds :
        attemptState[k] \in {"serialized", "running", "failed", "succeeded", "stale"}
            => capturedVersion[k] \in 0..MAX_VERSION

CurrentResultSafety ==
    task = "succeeded" => futureVersion = capturedVersion[currentAttempt]

StaleResultSafety ==
    \A k \in AttemptIds :
        resultWire[k] = "consumed" /\ k # currentAttempt
            => attemptState[k] = "stale"

=============================================================================
