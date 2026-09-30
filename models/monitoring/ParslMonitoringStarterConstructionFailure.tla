--------------------------- MODULE ParslMonitoringStarterConstructionFailure ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Monitoring database starter construction failure.
 *
 * dbm_starter assigns dbm only after DatabaseManager construction succeeds,
 * but its exception handler unconditionally calls dbm.close().  A constructor
 * failure therefore masks the original error with an unbound-local failure.
 * USE_FIXED models preserving the original startup failure.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES dbm, outcome
vars == <<dbm, outcome>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ dbm = "unbound"
    /\ outcome = "starting"

ConstructorFails ==
    /\ dbm = "unbound"
    /\ dbm' = "unbound"
    /\ outcome' = IF USE_FIXED THEN "original_failure" ELSE "masked_failure"

Next ==
    \/ ConstructorFails
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ dbm = "unbound"
    /\ outcome \in {"starting", "original_failure", "masked_failure"}

ConstructionFailureSafety == outcome # "masked_failure"

=============================================================================
