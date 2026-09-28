--------------------------- MODULE ParslBlockProviderBadStateMutation ---------------------------
EXTENDS Naturals

(***************************************************************************
 * set_bad_state_and_fail_all iterates the live _tasks dictionary.  Future
 * set_exception executes callbacks synchronously; a callback can therefore
 * mutate _tasks while the failure sweep is in progress.  USE_FIXED models
 * iterating a snapshot and preserving the original task set's failure sweep.
 *************************************************************************** *)

CONSTANT USE_FIXED

VARIABLES taskSet, pending, bad, callbackMutation, sweepError
vars == <<taskSet, pending, bad, callbackMutation, sweepError>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ taskSet = {"first", "second"}
    /\ pending = {"first", "second"}
    /\ bad = FALSE
    /\ callbackMutation = FALSE
    /\ sweepError = FALSE

FailFirst ==
    /\ ~bad
    /\ bad' = TRUE
    /\ callbackMutation' = TRUE
    /\ sweepError' = ~USE_FIXED
    /\ taskSet' = IF USE_FIXED THEN taskSet ELSE taskSet \cup {"callback-task"}
    /\ pending' = IF USE_FIXED THEN {} ELSE {"second"}

Done ==
    /\ bad
    /\ UNCHANGED vars

Next == FailFirst \/ Done
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ taskSet \subseteq {"first", "second", "callback-task"}
    /\ pending \subseteq taskSet
    /\ bad \in BOOLEAN
    /\ callbackMutation \in BOOLEAN
    /\ sweepError \in BOOLEAN

OriginalTasksFailed ==
    bad => pending = {}

=============================================================================
