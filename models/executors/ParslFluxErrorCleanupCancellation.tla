--------------------------- MODULE ParslFluxErrorCleanupCancellation ---------------------------
EXTENDS Naturals

(***************************************************************************
 * FluxExecutor._error_out_jobs drains submitted job records after a submit
 * thread failure.  The current implementation calls set_exception on every
 * Future without checking cancellation.  A canceled first Future can raise
 * InvalidStateError and strand later queued Futures.  USE_FIXED skips terminal
 * Futures and continues draining the queue.
 *************************************************************************** *)

CONSTANT USE_FIXED

VARIABLES queue, firstState, secondState, collectorAlive
vars == <<queue, firstState, secondState, collectorAlive>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ queue = 2
    /\ firstState = "cancelled"
    /\ secondState = "pending"
    /\ collectorAlive = TRUE

ProcessFirst ==
    /\ queue = 2
    /\ IF USE_FIXED
          THEN /\ queue' = 1
               /\ firstState' = "cancelled"
               /\ collectorAlive' = TRUE
          ELSE /\ queue' = 1
               /\ firstState' = "callback-error"
               /\ collectorAlive' = FALSE
    /\ UNCHANGED secondState

ProcessSecond ==
    /\ queue = 1
    /\ collectorAlive
    /\ queue' = 0
    /\ secondState' = "failed"
    /\ UNCHANGED <<firstState, collectorAlive>>

Done ==
    /\ queue = 0
    /\ UNCHANGED vars

Next == ProcessFirst \/ ProcessSecond \/ Done
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ queue \in 0..2
    /\ firstState \in {"cancelled", "callback-error"}
    /\ secondState \in {"pending", "failed"}
    /\ collectorAlive \in BOOLEAN

NoOrphanedPendingFuture ==
    ~collectorAlive => secondState # "pending"

DrainProgress ==
    secondState = "failed" => queue = 0

=============================================================================
