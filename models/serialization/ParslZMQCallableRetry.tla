------------------------ MODULE ParslZMQCallableRetry ------------------------
EXTENDS Naturals, Integers

(***************************************************************************
 * Callable/object snapshots over a bounded ZMQ-like task/result path.
 *
 * Each physical attempt captures the submitting process's callable/object
 * version before its task frame is delivered.  A failed attempt may publish
 * a valid serialized result after a retry has captured a newer version.  The
 * logical Future must correlate both the attempt and the captured payload.
 ***************************************************************************)

CONSTANTS MAX_VERSION, MAX_RETRIES, USE_FIXED

Attempts == 0..MAX_RETRIES
TaskStates == {"pending", "running", "retry_wait", "succeeded", "failed"}
AttemptStates == {"absent", "serialized", "running", "failed", "succeeded", "stale"}
WireStates == {"none", "queued", "consumed"}

VARIABLES sourceVersion, currentAttempt, task, capturedVersion, attemptState,
          taskWire, resultWire, resultVersion, futureVersion

vars == <<sourceVersion, currentAttempt, task, capturedVersion, attemptState,
           taskWire, resultWire, resultVersion, futureVersion>>

Init ==
    /\ MAX_VERSION >= 1
    /\ MAX_RETRIES >= 1
    /\ USE_FIXED \in BOOLEAN
    /\ sourceVersion = 0
    /\ currentAttempt = 0
    /\ task = "pending"
    /\ capturedVersion = [k \in Attempts |-> -1]
    /\ attemptState = [k \in Attempts |-> "absent"]
    /\ taskWire = [k \in Attempts |-> "none"]
    /\ resultWire = [k \in Attempts |-> "none"]
    /\ resultVersion = [k \in Attempts |-> -1]
    /\ futureVersion = -1

SerializeAttempt ==
    /\ task = "pending"
    /\ attemptState[currentAttempt] = "absent"
    /\ capturedVersion' = [capturedVersion EXCEPT ![currentAttempt] = sourceVersion]
    /\ attemptState' = [attemptState EXCEPT ![currentAttempt] = "serialized"]
    /\ taskWire' = [taskWire EXCEPT ![currentAttempt] = "queued"]
    /\ task' = "running"
    /\ UNCHANGED <<sourceVersion, currentAttempt, resultWire,
                    resultVersion, futureVersion>>

DeliverTask ==
    /\ task = "running"
    /\ attemptState[currentAttempt] = "serialized"
    /\ taskWire[currentAttempt] = "queued"
    /\ taskWire' = [taskWire EXCEPT ![currentAttempt] = "consumed"]
    /\ attemptState' = [attemptState EXCEPT ![currentAttempt] = "running"]
    /\ UNCHANGED <<sourceVersion, currentAttempt, task, capturedVersion,
                    resultWire, resultVersion, futureVersion>>

MutateSource ==
    /\ task = "running"
    /\ sourceVersion < MAX_VERSION
    /\ sourceVersion' = sourceVersion + 1
    /\ UNCHANGED <<currentAttempt, task, capturedVersion, attemptState,
                    taskWire, resultWire, resultVersion, futureVersion>>

FailAttempt ==
    /\ task = "running"
    /\ attemptState[currentAttempt] = "running"
    /\ attemptState' = [attemptState EXCEPT ![currentAttempt] = "failed"]
    /\ task' = IF currentAttempt < MAX_RETRIES THEN "retry_wait" ELSE "failed"
    /\ UNCHANGED <<sourceVersion, currentAttempt, capturedVersion, taskWire,
                    resultWire, resultVersion, futureVersion>>

Retry ==
    /\ task = "retry_wait"
    /\ currentAttempt < MAX_RETRIES
    /\ currentAttempt' = currentAttempt + 1
    /\ task' = "pending"
    /\ UNCHANGED <<sourceVersion, capturedVersion, attemptState, taskWire,
                    resultWire, resultVersion, futureVersion>>

CompleteAttempt(k) ==
    /\ k \in Attempts
    /\ attemptState[k] = "running"
    /\ attemptState' = [attemptState EXCEPT ![k] = "succeeded"]
    /\ resultWire' = [resultWire EXCEPT ![k] = "queued"]
    /\ resultVersion' = [resultVersion EXCEPT ![k] = capturedVersion[k]]
    /\ UNCHANGED <<sourceVersion, currentAttempt, task, capturedVersion,
                    taskWire, futureVersion>>

LateComplete(k) ==
    /\ k \in Attempts
    /\ attemptState[k] = "failed"
    /\ resultWire[k] = "none"
    /\ resultWire' = [resultWire EXCEPT ![k] = "queued"]
    /\ resultVersion' = [resultVersion EXCEPT ![k] = capturedVersion[k]]
    /\ UNCHANGED <<sourceVersion, currentAttempt, task, capturedVersion,
                    attemptState, taskWire, futureVersion>>

DeliverResult(k) ==
    /\ k \in Attempts
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
    /\ UNCHANGED <<sourceVersion, currentAttempt, capturedVersion,
                    taskWire, resultVersion>>

Next ==
    \/ SerializeAttempt
    \/ DeliverTask
    \/ MutateSource
    \/ FailAttempt
    \/ Retry
    \/ \E k \in Attempts : CompleteAttempt(k) \/ LateComplete(k) \/ DeliverResult(k)
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ sourceVersion \in 0..MAX_VERSION
    /\ currentAttempt \in Attempts
    /\ task \in TaskStates
    /\ capturedVersion \in [Attempts -> -1..MAX_VERSION]
    /\ attemptState \in [Attempts -> AttemptStates]
    /\ taskWire \in [Attempts -> WireStates]
    /\ resultWire \in [Attempts -> WireStates]
    /\ resultVersion \in [Attempts -> -1..MAX_VERSION]
    /\ futureVersion \in -1..MAX_VERSION

RetryBound == currentAttempt <= MAX_RETRIES

SnapshotSafety ==
    \A k \in Attempts :
        attemptState[k] \in {"serialized", "running", "failed", "succeeded", "stale"}
            => capturedVersion[k] \in 0..MAX_VERSION

SourceIsolation ==
    \A k \in Attempts : capturedVersion[k] # -1 => capturedVersion[k] <= sourceVersion

TransportSafety ==
    \A k \in Attempts :
        attemptState[k] = "running" => taskWire[k] = "consumed"

CurrentResultSafety ==
    task = "succeeded" => futureVersion = capturedVersion[currentAttempt]

StaleResultSafety ==
    \A k \in Attempts :
        resultWire[k] = "consumed" /\ k # currentAttempt => attemptState[k] = "stale"

=============================================================================
