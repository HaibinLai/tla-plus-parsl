--------------------------- MODULE ParslResultRace ---------------------------
EXTENDS Naturals, FiniteSets

(***************************************************************************
 * Result/failure callback race for one logical task.
 *
 * A physical attempt may emit a failure callback, cause a retry, and still
 * have a success result arrive later.  The callback is correlated by the
 * physical attempt id; only the current attempt may resolve the Future.
 ***************************************************************************)

CONSTANT MAX_RETRIES
AttemptIds == 0..MAX_RETRIES
AttemptStates == {"absent", "running", "failed", "completed"}
FutureStates == {"pending", "resolved", "rejected"}
QueueStates == {"none", "success", "failure", "consumed"}
Dispositions == {"none", "accepted", "stale"}

VARIABLES currentAttempt, attemptState, futureState, resultQueue,
          lateSuccess, resultDisposition
vars == <<currentAttempt, attemptState, futureState, resultQueue,
          lateSuccess, resultDisposition>>

Init ==
    /\ MAX_RETRIES >= 0
    /\ currentAttempt = 0
    /\ attemptState = [k \in AttemptIds |-> "absent"]
    /\ futureState = "pending"
    /\ resultQueue = [k \in AttemptIds |-> "none"]
    /\ lateSuccess = [k \in AttemptIds |-> FALSE]
    /\ resultDisposition = [k \in AttemptIds |-> "none"]

StartAttempt(k) ==
    /\ k = currentAttempt
    /\ futureState = "pending"
    /\ attemptState[k] = "absent"
    /\ attemptState' = [attemptState EXCEPT ![k] = "running"]
    /\ UNCHANGED <<currentAttempt, futureState, resultQueue,
                    lateSuccess, resultDisposition>>

CompleteAttempt(k) ==
    /\ k = currentAttempt
    /\ attemptState[k] = "running"
    /\ attemptState' = [attemptState EXCEPT ![k] = "completed"]
    /\ resultQueue' = [resultQueue EXCEPT ![k] = "success"]
    /\ UNCHANGED <<currentAttempt, futureState, lateSuccess, resultDisposition>>

FailAttempt(k) ==
    /\ k = currentAttempt
    /\ attemptState[k] = "running"
    /\ attemptState' = [attemptState EXCEPT ![k] = "failed"]
    /\ resultQueue' = [resultQueue EXCEPT ![k] = "failure"]
    /\ UNCHANGED <<currentAttempt, futureState, lateSuccess, resultDisposition>>

LateSuccess(k) ==
    /\ attemptState[k] = "failed"
    /\ ~lateSuccess[k]
    /\ lateSuccess' = [lateSuccess EXCEPT ![k] = TRUE]
    /\ UNCHANGED <<currentAttempt, attemptState, futureState,
                    resultQueue, resultDisposition>>

DeliverFailure(k) ==
    /\ resultQueue[k] = "failure"
    /\ resultQueue' = [resultQueue EXCEPT ![k] = "consumed"]
    /\ resultDisposition' = [resultDisposition EXCEPT ![k] =
          IF k = currentAttempt /\ futureState = "pending"
          THEN "accepted" ELSE "stale"]
    /\ IF k = currentAttempt /\ futureState = "pending"
       THEN IF k < MAX_RETRIES
            THEN /\ currentAttempt' = currentAttempt + 1
                 /\ futureState' = futureState
            ELSE /\ currentAttempt' = currentAttempt
                 /\ futureState' = "rejected"
       ELSE UNCHANGED <<currentAttempt, futureState>>
    /\ UNCHANGED <<attemptState, lateSuccess>>

DeliverSuccess(k) ==
    /\ resultQueue[k] = "success" \/ lateSuccess[k]
    /\ resultQueue' = [resultQueue EXCEPT ![k] = "consumed"]
    /\ lateSuccess' = [lateSuccess EXCEPT ![k] = FALSE]
    /\ resultDisposition' = [resultDisposition EXCEPT ![k] =
          IF k = currentAttempt /\ futureState = "pending"
          THEN "accepted" ELSE "stale"]
    /\ futureState' = IF k = currentAttempt /\ futureState = "pending"
                      THEN "resolved" ELSE futureState
    /\ attemptState' = [attemptState EXCEPT ![k] =
          IF k = currentAttempt /\ futureState = "pending"
          THEN "completed" ELSE @]
    /\ UNCHANGED currentAttempt

Next ==
    \/ \E k \in AttemptIds : StartAttempt(k)
    \/ \E k \in AttemptIds : CompleteAttempt(k) \/ FailAttempt(k)
    \/ \E k \in AttemptIds : LateSuccess(k)
    \/ \E k \in AttemptIds : DeliverFailure(k) \/ DeliverSuccess(k)
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ currentAttempt \in AttemptIds
    /\ attemptState \in [AttemptIds -> AttemptStates]
    /\ futureState \in FutureStates
    /\ resultQueue \in [AttemptIds -> QueueStates]
    /\ lateSuccess \in [AttemptIds -> BOOLEAN]
    /\ resultDisposition \in [AttemptIds -> Dispositions]

RetryBound == currentAttempt <= MAX_RETRIES

FutureConsistency ==
    /\ futureState = "resolved" =>
          resultDisposition[currentAttempt] = "accepted"
    /\ futureState = "rejected" =>
          resultDisposition[currentAttempt] = "accepted"
              \/ attemptState[currentAttempt] = "failed"

StaleSafety ==
    \A k \in AttemptIds : resultDisposition[k] = "stale"
        => k # currentAttempt \/ futureState # "pending"

=============================================================================
