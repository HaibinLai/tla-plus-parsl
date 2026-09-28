--------------------------- MODULE ParslTaskVineCancelledResult ---------------------------
EXTENDS Naturals

(***************************************************************************
 * TaskVine collector delivery racing with user cancellation.  The current
 * collector pops the task and calls set_result without checking cancellation;
 * InvalidStateError exits the collector and its cleanup fails unrelated
 * tasks.  USE_FIXED discards the stale report and continues.
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

ReceiveCancelledReport ==
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

Next == ReceiveCancelledReport \/ ReceiveLiveReport \/ FinallyFailure \/ Done
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ firstState = "cancelled"
    /\ secondState \in {"pending", "done"}
    /\ firstPresent \in BOOLEAN
    /\ secondPresent \in BOOLEAN
    /\ collectorAlive \in BOOLEAN
    /\ batchDone \in BOOLEAN
    /\ secondError \in {"none", "manager-failure"}

CancelledReportDoesNotKillCollector ==
    firstState = "cancelled" => collectorAlive

BatchCompletionSafety ==
    batchDone => /\ secondState = "done" /\ ~secondPresent /\ secondError = "none"

=============================================================================
