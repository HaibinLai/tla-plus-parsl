--------------------------- MODULE ParslHtexCancelledFailureResult ---------------------------
EXTENDS Naturals

(***************************************************************************
 * HTEX failure delivery races with user cancellation.  The current result
 * thread removes the Future and calls set_exception for a failure frame.
 * Future.set_exception raises InvalidStateError for a cancelled Future; the
 * recovery attempt in the current implementation can raise again, so the
 * result thread exits and later frames remain unprocessed.  USE_FIXED models
 * ignoring terminal Futures and continuing the batch.
 *************************************************************************** *)

CONSTANT USE_FIXED

VARIABLES firstState, secondState, firstPresent, secondPresent,
          workerAlive, batchDone
vars == <<firstState, secondState, firstPresent, secondPresent,
          workerAlive, batchDone>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ firstState = "cancelled"
    /\ secondState = "pending"
    /\ firstPresent = TRUE
    /\ secondPresent = TRUE
    /\ workerAlive = TRUE
    /\ batchDone = FALSE

ReceiveCancelledFailure ==
    /\ workerAlive /\ firstPresent
    /\ firstPresent' = FALSE
    /\ workerAlive' = IF USE_FIXED THEN TRUE ELSE FALSE
    /\ UNCHANGED <<firstState, secondState, secondPresent, batchDone>>

ReceiveLiveFailure ==
    /\ workerAlive /\ secondPresent
    /\ secondPresent' = FALSE
    /\ secondState' = "failed"
    /\ batchDone' = TRUE
    /\ UNCHANGED <<firstState, firstPresent, workerAlive>>

Done ==
    /\ ~workerAlive \/ batchDone
    /\ UNCHANGED vars

Next == ReceiveCancelledFailure \/ ReceiveLiveFailure \/ Done
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ firstState = "cancelled"
    /\ secondState \in {"pending", "failed"}
    /\ firstPresent \in BOOLEAN
    /\ secondPresent \in BOOLEAN
    /\ workerAlive \in BOOLEAN
    /\ batchDone \in BOOLEAN

CancelledFailureDoesNotKillWorker ==
    firstState = "cancelled" => workerAlive

BatchFailureCompletionSafety ==
    batchDone => /\ secondState = "failed" /\ ~secondPresent

=============================================================================
