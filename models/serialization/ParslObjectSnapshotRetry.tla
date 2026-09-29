--------------------------- MODULE ParslObjectSnapshotRetry ---------------------------
EXTENDS Naturals, Integers

(***************************************************************************
 * Mutable Python object snapshots across physical retries.
 *
 * Each attempt should serialize the callable/argument object graph at its
 * own submission boundary.  A cache keyed only by object identity can reuse
 * the first payload after the object mutates.  The current branch reuses that
 * payload for a retry; the fixed branch captures the new object version.
 ***************************************************************************)

CONSTANTS MAX_VERSION, MAX_RETRIES, USE_FIXED

AttemptStates == {"absent", "running", "failed", "succeeded"}
TaskStates == {"pending", "running", "retry_wait", "succeeded"}

VARIABLES objectVersion, cacheVersion, currentAttempt, task,
          attemptState, capturedVersion, payloadVersion, resultVersion
vars == <<objectVersion, cacheVersion, currentAttempt, task,
           attemptState, capturedVersion, payloadVersion, resultVersion>>

Init ==
    /\ MAX_VERSION >= 1
    /\ MAX_RETRIES >= 1
    /\ USE_FIXED \in BOOLEAN
    /\ objectVersion = 0
    /\ cacheVersion = -1
    /\ currentAttempt = 0
    /\ task = "pending"
    /\ attemptState = [k \in 0..MAX_RETRIES |-> "absent"]
    /\ capturedVersion = [k \in 0..MAX_RETRIES |-> -1]
    /\ payloadVersion = [k \in 0..MAX_RETRIES |-> -1]
    /\ resultVersion = -1

SerializeAttempt ==
    /\ task = "pending"
    /\ attemptState[currentAttempt] = "absent"
    /\ capturedVersion' = [capturedVersion EXCEPT ![currentAttempt] = objectVersion]
    /\ payloadVersion' = [payloadVersion EXCEPT ![currentAttempt] =
          IF USE_FIXED /\ cacheVersion # objectVersion
          THEN objectVersion
          ELSE IF cacheVersion = -1 THEN objectVersion ELSE cacheVersion]
    /\ cacheVersion' = IF USE_FIXED THEN objectVersion
                       ELSE IF cacheVersion = -1 THEN objectVersion ELSE cacheVersion
    /\ attemptState' = [attemptState EXCEPT ![currentAttempt] = "running"]
    /\ task' = "running"
    /\ UNCHANGED <<objectVersion, currentAttempt, resultVersion>>

MutateObject ==
    /\ task = "running"
    /\ objectVersion < MAX_VERSION
    /\ objectVersion' = objectVersion + 1
    /\ UNCHANGED <<cacheVersion, currentAttempt, task, attemptState,
                    capturedVersion, payloadVersion, resultVersion>>

FailAttempt ==
    /\ task = "running"
    /\ attemptState[currentAttempt] = "running"
    /\ attemptState' = [attemptState EXCEPT ![currentAttempt] = "failed"]
    /\ task' = IF currentAttempt < MAX_RETRIES THEN "retry_wait" ELSE task
    /\ UNCHANGED <<objectVersion, cacheVersion, currentAttempt,
                    capturedVersion, payloadVersion, resultVersion>>

Retry ==
    /\ task = "retry_wait"
    /\ currentAttempt < MAX_RETRIES
    /\ currentAttempt' = currentAttempt + 1
    /\ task' = "pending"
    /\ UNCHANGED <<objectVersion, cacheVersion, attemptState,
                    capturedVersion, payloadVersion, resultVersion>>

CompleteAttempt ==
    /\ task = "running"
    /\ attemptState[currentAttempt] = "running"
    /\ attemptState' = [attemptState EXCEPT ![currentAttempt] = "succeeded"]
    /\ resultVersion' = payloadVersion[currentAttempt]
    /\ task' = "succeeded"
    /\ UNCHANGED <<objectVersion, cacheVersion, currentAttempt,
                    capturedVersion, payloadVersion>>

Next ==
    \/ SerializeAttempt
    \/ MutateObject
    \/ FailAttempt
    \/ Retry
    \/ CompleteAttempt
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ objectVersion \in 0..MAX_VERSION
    /\ cacheVersion \in -1..MAX_VERSION
    /\ currentAttempt \in 0..MAX_RETRIES
    /\ task \in TaskStates
    /\ attemptState \in [0..MAX_RETRIES -> AttemptStates]
    /\ capturedVersion \in [0..MAX_RETRIES -> -1..MAX_VERSION]
    /\ payloadVersion \in [0..MAX_RETRIES -> -1..MAX_VERSION]
    /\ resultVersion \in -1..MAX_VERSION

RetryBound == currentAttempt <= MAX_RETRIES

SnapshotSafety ==
    task = "succeeded" => resultVersion = capturedVersion[currentAttempt]

ResultVersionSafety ==
    task = "succeeded" => resultVersion <= objectVersion

TerminalStability ==
    task = "succeeded" => attemptState[currentAttempt] = "succeeded"

=============================================================================
