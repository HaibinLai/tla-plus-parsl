--------------------------- MODULE ParslWorkQueueCancelledResult ---------------------------
EXTENDS Naturals

(***************************************************************************
 * WorkQueue collector delivery racing with user cancellation.  The current
 * collector removes a Future and calls set_result unconditionally.  A
 * cancelled Future raises InvalidStateError, exits the collector, and its
 * finally block fails unrelated pending tasks.  USE_FIXED discards the stale
 * result and continues collecting the batch.
 *************************************************************************** *)

CONSTANT USE_FIXED

VARIABLES firstState, secondState, firstPresent, secondPresent,
          collectorAlive, batchDone, secondError
vars == <<firstState, secondState, firstPresent, secondPresent,
          collectorAlive, batchDone, secondError>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ firstState = "cancelled"
    /\ secondState = "pending"
    /\ firstPresent = TRUE
    /\ secondPresent = TRUE
    /\ collectorAlive = TRUE
    /\ batchDone = FALSE
    /\ secondError = "none"

ReceiveCancelledResult ==
    /\ collectorAlive /\ firstPresent
    /\ firstPresent' = FALSE
    /\ collectorAlive' = IF USE_FIXED THEN TRUE ELSE FALSE
    /\ IF USE_FIXED THEN secondError' = "none" ELSE secondError' = "executor-failure"
    /\ UNCHANGED <<firstState, secondState, secondPresent, batchDone>>

ReceiveLiveResult ==
    /\ collectorAlive /\ secondPresent
    /\ secondPresent' = FALSE
    /\ secondState' = "done"
    /\ batchDone' = TRUE
    /\ UNCHANGED <<firstState, firstPresent, collectorAlive, secondError>>

FinallyFailure ==
    /\ ~collectorAlive
    /\ secondPresent
    /\ secondPresent' = FALSE
    /\ secondError' = "executor-failure"
    /\ UNCHANGED <<firstState, secondState, firstPresent,
                    collectorAlive, batchDone>>

Done ==
    /\ batchDone \/ (secondError = "executor-failure")
    /\ UNCHANGED vars

Next == ReceiveCancelledResult \/ ReceiveLiveResult \/ FinallyFailure \/ Done
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ firstState = "cancelled"
    /\ secondState \in {"pending", "done"}
    /\ firstPresent \in BOOLEAN
    /\ secondPresent \in BOOLEAN
    /\ collectorAlive \in BOOLEAN
    /\ batchDone \in BOOLEAN
    /\ secondError \in {"none", "executor-failure"}

CancelledResultDoesNotKillCollector ==
    firstState = "cancelled" => collectorAlive

BatchCompletionSafety ==
    batchDone => /\ secondState = "done" /\ ~secondPresent /\ secondError = "none"

=============================================================================
