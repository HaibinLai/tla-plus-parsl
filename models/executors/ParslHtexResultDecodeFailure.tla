--------------------------- MODULE ParslHtexResultDecodeFailure ---------------------------
EXTENDS Naturals

(***************************************************************************
 * HTEX result deserialization failure after task-map removal.
 *
 * The current result worker removes the Future from ``tasks`` before calling
 * deserialize on a result payload. A corrupt result therefore exits the
 * worker with the Future pending and no longer reachable by cleanup. The
 * FIXED branch completes the Future with a deserialization error and keeps
 * the result worker alive for later messages.
 *************************************************************************** *)

CONSTANT USE_FIXED
VARIABLES futureState, taskPresent, workerAlive, corruptObserved, errorDelivered
vars == <<futureState, taskPresent, workerAlive, corruptObserved, errorDelivered>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ futureState = "pending"
    /\ taskPresent = TRUE
    /\ workerAlive = TRUE
    /\ corruptObserved = FALSE
    /\ errorDelivered = FALSE

DeliverCorruptResult ==
    /\ workerAlive
    /\ taskPresent
    /\ corruptObserved' = TRUE
    /\ taskPresent' = FALSE
    /\ IF USE_FIXED
          THEN /\ futureState' = "failed"
               /\ workerAlive' = TRUE
               /\ errorDelivered' = TRUE
          ELSE /\ futureState' = "pending"
               /\ workerAlive' = FALSE
               /\ errorDelivered' = FALSE

Next ==
    \/ DeliverCorruptResult
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ futureState \in {"pending", "failed"}
    /\ taskPresent \in BOOLEAN
    /\ workerAlive \in BOOLEAN
    /\ corruptObserved \in BOOLEAN
    /\ errorDelivered \in BOOLEAN

DecodeFailureSafety ==
    corruptObserved => futureState = "failed" /\ errorDelivered

NoOrphanedPendingFuture ==
    ~workerAlive => futureState = "failed"

=============================================================================
