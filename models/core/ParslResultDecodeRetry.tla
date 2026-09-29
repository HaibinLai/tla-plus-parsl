--------------------------- MODULE ParslResultDecodeRetry ---------------------------
EXTENDS Naturals

(***************************************************************************
 * ZMQ/result deserialization failure joined with physical retry.
 *
 * A worker finishes attempt 0 and sends a result frame.  The manager can
 * fail to decode that frame, mark the attempt lost, and start attempt 1.
 * The old frame may still be delivered after the retry is running.  The
 * current branch accepts it as the logical result; the fixed branch marks it
 * stale unless it belongs to the current attempt.
 ***************************************************************************)

CONSTANTS MAX_RETRIES, USE_FIXED

AttemptIds == 0..MAX_RETRIES
AttemptStates == {"absent", "running", "done", "lost"}
TaskStates == {"pending", "running", "retry_wait", "succeeded", "failed"}
WireStates == {"none", "queued", "corrupt", "decoded", "stale", "resolved"}

VARIABLES task, currentAttempt, attemptState, resultWire, future
vars == <<task, currentAttempt, attemptState, resultWire, future>>

Init ==
    /\ MAX_RETRIES >= 1
    /\ USE_FIXED \in BOOLEAN
    /\ task = "pending"
    /\ currentAttempt = 0
    /\ attemptState = [k \in AttemptIds |-> "absent"]
    /\ resultWire = [k \in AttemptIds |-> "none"]
    /\ future = "unresolved"

Submit ==
    /\ task = "pending"
    /\ attemptState[currentAttempt] = "absent"
    /\ task' = "running"
    /\ attemptState' = [attemptState EXCEPT ![currentAttempt] = "running"]
    /\ UNCHANGED <<currentAttempt, resultWire, future>>

WorkerComplete ==
    /\ task = "running"
    /\ attemptState[currentAttempt] = "running"
    /\ attemptState' = [attemptState EXCEPT ![currentAttempt] = "done"]
    /\ resultWire' = [resultWire EXCEPT ![currentAttempt] = "queued"]
    /\ UNCHANGED <<task, currentAttempt, future>>

DecodeFailure ==
    /\ task = "running"
    /\ attemptState[currentAttempt] = "done"
    /\ resultWire[currentAttempt] = "queued"
    /\ attemptState' = [attemptState EXCEPT ![currentAttempt] = "lost"]
    /\ resultWire' = [resultWire EXCEPT ![currentAttempt] = "corrupt"]
    /\ task' = IF currentAttempt < MAX_RETRIES THEN "retry_wait" ELSE "failed"
    /\ future' = IF currentAttempt = MAX_RETRIES THEN "rejected" ELSE future
    /\ UNCHANGED currentAttempt

Retry ==
    /\ task = "retry_wait"
    /\ currentAttempt < MAX_RETRIES
    /\ currentAttempt' = currentAttempt + 1
    /\ task' = "pending"
    /\ UNCHANGED <<attemptState, resultWire, future>>

DecodeResult(k) ==
    /\ k \in AttemptIds
    /\ resultWire[k] = "queued" \/ resultWire[k] = "corrupt"
    /\ IF USE_FIXED
       THEN IF k = currentAttempt /\ attemptState[k] = "done"
            THEN /\ resultWire' = [resultWire EXCEPT ![k] = "resolved"]
                 /\ future' = "resolved"
                 /\ task' = "succeeded"
            ELSE /\ resultWire' = [resultWire EXCEPT ![k] = "stale"]
                 /\ UNCHANGED <<future, task>>
       ELSE /\ resultWire' = [resultWire EXCEPT ![k] = "resolved"]
            /\ future' = "resolved"
            /\ task' = "succeeded"
    /\ UNCHANGED <<currentAttempt, attemptState>>

CompleteRetry ==
    /\ task = "running"
    /\ attemptState[currentAttempt] = "running"
    /\ attemptState' = [attemptState EXCEPT ![currentAttempt] = "done"]
    /\ resultWire' = [resultWire EXCEPT ![currentAttempt] = "resolved"]
    /\ task' = "succeeded"
    /\ future' = "resolved"
    /\ UNCHANGED currentAttempt

Next ==
    \/ Submit
    \/ WorkerComplete
    \/ DecodeFailure
    \/ Retry
    \/ \E k \in AttemptIds : DecodeResult(k)
    \/ CompleteRetry
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ task \in TaskStates
    /\ currentAttempt \in AttemptIds
    /\ attemptState \in [AttemptIds -> AttemptStates]
    /\ resultWire \in [AttemptIds -> WireStates]
    /\ future \in {"unresolved", "resolved", "rejected"}

RetryBound == currentAttempt <= MAX_RETRIES

DecodeSafety ==
    future = "resolved" => task = "succeeded"

CurrentAttemptSafety ==
    future = "resolved" => attemptState[currentAttempt] = "done"

StaleSafety ==
    \A k \in AttemptIds : resultWire[k] = "stale" =>
        ~(k = currentAttempt /\ attemptState[k] = "done")

TerminalSafety ==
    task = "succeeded" => future = "resolved"

=============================================================================
