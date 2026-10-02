--------------------------- MODULE ParslHtexResultTaskIdShape ---------------------------
EXTENDS Naturals

(***************************************************************************
 * HTEX executor-side result task-id validation.
 *
 * _result_queue_worker uses the decoded task_id as a dictionary key before
 * validating its type.  An unhashable result ID can therefore kill the
 * result worker and strand unrelated valid Futures in the same batch.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES workerAlive, validFuture, malformedSeen, validDelivered
vars == <<workerAlive, validFuture, malformedSeen, validDelivered>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ workerAlive = TRUE
    /\ validFuture = "pending"
    /\ malformedSeen = FALSE
    /\ validDelivered = FALSE

DeliverMalformedId ==
    /\ workerAlive
    /\ malformedSeen' = TRUE
    /\ IF USE_FIXED
          THEN workerAlive' = TRUE
          ELSE workerAlive' = FALSE
    /\ UNCHANGED <<validFuture, validDelivered>>

DeliverValidId ==
    /\ workerAlive
    /\ validFuture = "pending"
    /\ validFuture' = "done"
    /\ validDelivered' = TRUE
    /\ UNCHANGED <<workerAlive, malformedSeen>>

Next ==
    \/ DeliverMalformedId
    \/ DeliverValidId
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ workerAlive \in BOOLEAN
    /\ validFuture \in {"pending", "done"}
    /\ malformedSeen \in BOOLEAN
    /\ validDelivered \in BOOLEAN

MalformedIsolation ==
    malformedSeen => workerAlive

BatchProgress ==
    malformedSeen /\ USE_FIXED => validDelivered

=============================================================================
