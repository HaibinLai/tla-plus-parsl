--------------------------- MODULE ParslHtexManagerLossSendFailure ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Manager-loss synthetic result and transport failure.
 *
 * Interchange.expire_bad_managers emits a ManagerLost result for each task
 * before removing the expired manager.  The Current branch leaves the
 * manager/task/Future unresolved if that result send fails.  The Fixed branch
 * records an explicit terminal manager-loss outcome even when transport
 * delivery is unavailable.
 ***************************************************************************)

CONSTANT USE_FIXED
VARIABLES managerState, sendState, futureState
vars == <<managerState, sendState, futureState>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ managerState = "live"
    /\ sendState = "ready"
    /\ futureState = "pending"

ExpireManager ==
    /\ managerState = "live"
    /\ managerState' = "expiring"
    /\ UNCHANGED <<sendState, futureState>>

SendSyntheticLossFailure ==
    /\ managerState = "expiring"
    /\ sendState = "ready"
    /\ sendState' = "failed"
    /\ IF USE_FIXED
          THEN /\ managerState' = "expired"
               /\ futureState' = "manager_lost"
          ELSE /\ managerState' = "live"
               /\ UNCHANGED futureState

Next ==
    \/ ExpireManager
    \/ SendSyntheticLossFailure
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ managerState \in {"live", "expiring", "expired"}
    /\ sendState \in {"ready", "failed"}
    /\ futureState \in {"pending", "manager_lost"}

NoOrphanedLoss ==
    sendState = "failed" => futureState = "manager_lost"

TerminalManagerConsistency ==
    futureState = "manager_lost" => managerState = "expired"

=============================================================================
