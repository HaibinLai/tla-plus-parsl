--------------------------- MODULE ParslHtexManagerLoss ---------------------------
EXTENDS Naturals

(***************************************************************************
 * HTEX manager heartbeat loss to Future failure.
 *
 * Interchange expiry removes the manager and emits a synthetic result for
 * each in-flight task.  The executor result worker consumes that envelope and
 * resolves the corresponding Future with ManagerLost.  USE_FIXED is a
 * regression guard: dropping the synthetic result leaves the Future pending.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES managerState, futureState, lossEnvelope, delivered
vars == <<managerState, futureState, lossEnvelope, delivered>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ managerState = "live"
    /\ futureState = "pending"
    /\ lossEnvelope = FALSE
    /\ delivered = FALSE

ExpireManager ==
    /\ managerState = "live"
    /\ managerState' = "expired"
    /\ lossEnvelope' = TRUE
    /\ UNCHANGED <<futureState, delivered>>

DeliverLoss ==
    /\ managerState = "expired"
    /\ lossEnvelope
    /\ delivered' = TRUE
    /\ futureState' = IF USE_FIXED THEN "manager_lost" ELSE "pending"
    /\ UNCHANGED <<managerState, lossEnvelope>>

Next == ExpireManager \/ DeliverLoss \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ managerState \in {"live", "expired"}
    /\ futureState \in {"pending", "manager_lost"}
    /\ lossEnvelope \in BOOLEAN
    /\ delivered \in BOOLEAN

ExpiredTaskSafety ==
    delivered => futureState = "manager_lost"

EnvelopeDeliverySafety ==
    delivered => managerState = "expired" /\ lossEnvelope

=============================================================================
