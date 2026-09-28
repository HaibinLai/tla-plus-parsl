--------------------------- MODULE ParslBlockProviderBadStateOrdering ---------------------------
EXTENDS Naturals

(***************************************************************************
 * set_bad_state_and_fail_all iterates _tasks and calls Future.set_exception
 * without checking whether each Future is already done.  If a completed
 * Future appears before an outstanding one, the first call raises
 * InvalidStateError and the later task is left pending.  USE_FIXED models
 * skipping already-terminal Futures.
 *************************************************************************** *)

CONSTANT USE_FIXED
Tasks == {"done", "pending"}

VARIABLES taskState, bad, callbackError
vars == <<taskState, bad, callbackError>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ taskState = [t \in Tasks |-> IF t = "done" THEN "succeeded" ELSE "pending"]
    /\ bad = FALSE
    /\ callbackError = FALSE

MarkBad ==
    /\ ~bad
    /\ bad' = TRUE
    /\ callbackError' = IF USE_FIXED THEN FALSE ELSE TRUE
    /\ taskState' = [t \in Tasks |->
          IF t = "pending" THEN
             IF USE_FIXED THEN "failed" ELSE "pending"
          ELSE taskState[t]]

Done ==
    /\ bad
    /\ UNCHANGED vars

Next == MarkBad \/ Done
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ taskState \in [Tasks -> {"succeeded", "pending", "failed"}]
    /\ bad \in BOOLEAN
    /\ callbackError \in BOOLEAN

OutstandingFailureSafety ==
    bad => taskState["pending"] = "failed"

=============================================================================
