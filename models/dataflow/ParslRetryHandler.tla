--------------------------- MODULE ParslRetryHandler ---------------------------
EXTENDS Naturals

(***************************************************************************
 * A retry_handler contributes fail_cost to the retry budget.  The current
 * DFK path accepts a zero cost, so a failed attempt can be retried even when
 * retries=0.  The FIXED branch charges at least one unit for every failure.
 *************************************************************************** *)

CONSTANTS RETRIES, HANDLER_COST, USE_FIXED

States == {"ready", "failed", "retrying", "terminal"}
VARIABLES state, failCost, tryId
vars == <<state, failCost, tryId>>

Init ==
    /\ RETRIES \in Nat
    /\ HANDLER_COST \in Nat
    /\ USE_FIXED \in BOOLEAN
    /\ state = "ready"
    /\ failCost = 0
    /\ tryId = 0

AttemptFails ==
    /\ state = "ready"
    /\ state' = "failed"
    /\ UNCHANGED <<failCost, tryId>>

HandleFailure ==
    /\ state = "failed"
    /\ IF USE_FIXED
          THEN failCost' = failCost + IF HANDLER_COST = 0 THEN 1 ELSE HANDLER_COST
          ELSE failCost' = failCost + HANDLER_COST
    /\ IF failCost' <= RETRIES
          THEN /\ state' = "retrying"
               /\ tryId' = tryId + 1
          ELSE /\ state' = "terminal"
               /\ UNCHANGED tryId

LaunchRetry ==
    /\ state = "retrying"
    /\ state' = "ready"
    /\ UNCHANGED <<failCost, tryId>>

Next ==
    \/ AttemptFails
    \/ HandleFailure
    \/ LaunchRetry
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in States
    /\ failCost \in Nat
    /\ tryId \in Nat

RetryLimitSafety == tryId <= RETRIES

=============================================================================
