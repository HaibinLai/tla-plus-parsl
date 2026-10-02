--------------------- MODULE ParslStagingProviderTransferFailure ---------------------
EXTENDS Naturals

(***************************************************************************
 * DataManager staging-provider transfer failure.
 *
 * DataManager selects the first provider whose can_stage_* predicate is true
 * and calls stage_in/stage_out without an exception boundary.  If that
 * transfer raises, later capable providers are never considered.  The Fixed
 * branch isolates the transfer failure and continues ordered dispatch.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES state
vars == <<state>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ state = "checking_first"

FirstTransferFails ==
    /\ state = "checking_first"
    /\ state' = IF USE_FIXED THEN "checking_second" ELSE "failed"

SelectSecond ==
    /\ state = "checking_second"
    /\ state' = "selected"

Next == FirstTransferFails \/ SelectSecond \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ state \in {"checking_first", "checking_second", "selected", "failed"}

LaterProviderAdmission == state # "failed"

=============================================================================
