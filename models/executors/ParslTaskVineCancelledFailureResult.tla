--------------------------- MODULE ParslTaskVineCancelledFailureResult ---------------------------
EXTENDS Naturals

(***************************************************************************
 * TaskVine collector delivery racing with user cancellation on the failure
 * result path.  The current collector unconditionally calls set_exception;
 * InvalidStateError exits the collector and cleanup fails unrelated tasks.
 * USE_FIXED discards the stale failure report and continues.
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

ReceiveCancelledFailureReport ==
    /\ collectorAlive /\ firstPresent
    /\ firstPresent' = FALSE
    /\ collectorAlive' = IF USE_FIXED THEN TRUE ELSE FALSE
    /\ IF USE_FIXED THEN secondError' = "none" ELSE secondError' = "manager-failure"
    /\ UNCHANGED <<firstState, secondState, secondPresent, batchDone>>

ReceiveLiveReport ==
    /\ collectorAlive /\ secondPresent
    /\ secondPresent' = FALSE
    /\ secondState' = "done"
    /\ batchDone' = TRUE
    /\ UNCHANGED <<firstState, firstPresent, collectorAlive, secondError>>

FinallyFailure ==
    /\ ~collectorAlive
    /\ secondPresent
    /\ secondPresent' = FALSE
    /\ secondError' = "manager-failure"
    /\ UNCHANGED <<firstState, secondState, firstPresent,
                    collectorAlive, batchDone>>

Done ==
    /\ batchDone \/ (secondError = "manager-failure")
    /\ UNCHANGED vars

Next == ReceiveCancelledFailureReport \/ ReceiveLiveReport \/ FinallyFailure \/ Done
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ firstState = "cancelled"
    /\ secondState \in {"pending", "done"}
    /\ firstPresent \in BOOLEAN
    /\ secondPresent \in BOOLEAN
    /\ collectorAlive \in BOOLEAN
    /\ batchDone \in BOOLEAN
    /\ secondError \in {"none", "manager-failure"}

CancelledFailureDoesNotKillCollector ==
    firstState = "cancelled" => collectorAlive

BatchCompletionSafety ==
    batchDone => /\ secondState = "done" /\ ~secondPresent /\ secondError = "none"

=============================================================================
