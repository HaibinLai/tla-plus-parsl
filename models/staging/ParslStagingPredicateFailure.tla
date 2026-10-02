--------------------------- MODULE ParslStagingPredicateFailure ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Ordered DataManager staging-provider selection with a predicate failure.
 *
 * DataManager scans providers in order.  A robust dispatcher should isolate a
 * failing can_stage_* predicate and continue to a later capable provider.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES index, selected, state
vars == <<index, selected, state>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ index = 1
    /\ selected = 0
    /\ state = "checking"

CheckFirst ==
    /\ index = 1
    /\ IF USE_FIXED
          THEN /\ index' = 2
               /\ state' = "checking"
          ELSE /\ index' = 1
               /\ state' = "failed"
    /\ UNCHANGED selected

SelectSecond ==
    /\ index = 2
    /\ selected' = 2
    /\ index' = 2
    /\ state' = "selected"

Next == CheckFirst \/ SelectSecond \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ index \in 1..2
    /\ selected \in 0..2
    /\ state \in {"checking", "selected", "failed"}

LaterProviderAdmission == state # "failed"

=============================================================================
