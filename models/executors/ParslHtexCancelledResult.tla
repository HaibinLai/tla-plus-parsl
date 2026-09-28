--------------------------- MODULE ParslHtexCancelledResult ---------------------------
EXTENDS Naturals

(***************************************************************************
 * HTEX result delivery races with user cancellation.  The current result
 * thread removes the Future and calls set_result without checking whether it
 * was cancelled.  concurrent.futures then raises InvalidStateError, which
 * exits the result thread and leaves later messages unprocessed.  USE_FIXED
 * models discarding a result for an already-cancelled Future and continuing
 * the batch.
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

ReceiveCancelledResult ==
    /\ workerAlive /\ firstPresent
    /\ firstPresent' = FALSE
    /\ workerAlive' = IF USE_FIXED THEN TRUE ELSE FALSE
    /\ UNCHANGED <<firstState, secondState, secondPresent, batchDone>>

ReceiveLiveResult ==
    /\ workerAlive /\ secondPresent
    /\ secondPresent' = FALSE
    /\ secondState' = "done"
    /\ batchDone' = TRUE
    /\ UNCHANGED <<firstState, firstPresent, workerAlive>>

Done ==
    /\ ~workerAlive \/ batchDone
    /\ UNCHANGED vars

Next == ReceiveCancelledResult \/ ReceiveLiveResult \/ Done
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ firstState = "cancelled"
    /\ secondState \in {"pending", "done"}
    /\ firstPresent \in BOOLEAN
    /\ secondPresent \in BOOLEAN
    /\ workerAlive \in BOOLEAN
    /\ batchDone \in BOOLEAN

CancelledResultDoesNotKillWorker ==
    firstState = "cancelled" => workerAlive

BatchCompletionSafety ==
    batchDone => /\ secondState = "done" /\ ~secondPresent

=============================================================================
