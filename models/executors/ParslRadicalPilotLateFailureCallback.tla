--------------------------- MODULE ParslRadicalPilotLateFailureCallback ---------------------------
EXTENDS Naturals

(***************************************************************************
 * RadicalPilotExecutor.task_state_cb maps a late FAILED callback directly
 * onto a Parsl Future.  After a CANCELED callback the Future is terminal;
 * the current callback calls set_exception unconditionally and the callback
 * path raises InvalidStateError.  USE_FIXED ignores terminal callbacks.
 *************************************************************************** *)

CONSTANT USE_FIXED

VARIABLES rpState, futureState, callbackAlive
vars == <<rpState, futureState, callbackAlive>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ rpState = "running"
    /\ futureState = "pending"
    /\ callbackAlive = TRUE

Cancel ==
    /\ rpState = "running"
    /\ rpState' = "canceled"
    /\ futureState' = "cancelled"
    /\ UNCHANGED callbackAlive

LateFailed ==
    /\ rpState = "canceled"
    /\ rpState' = "canceled"
    /\ IF USE_FIXED
          THEN /\ futureState' = "cancelled"
               /\ callbackAlive' = TRUE
          ELSE /\ futureState' = "callback-error"
               /\ callbackAlive' = FALSE

NormalFailed ==
    /\ rpState = "running"
    /\ rpState' = "failed"
    /\ futureState' = "failed"
    /\ UNCHANGED callbackAlive

Done ==
    /\ rpState \in {"failed", "canceled"}
    /\ UNCHANGED vars

Next == Cancel \/ LateFailed \/ NormalFailed \/ Done
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ rpState \in {"running", "failed", "canceled"}
    /\ futureState \in {"pending", "failed", "cancelled", "callback-error"}
    /\ callbackAlive \in BOOLEAN

LateFailureCallbackSafety ==
    rpState = "canceled" => callbackAlive

TerminalFutureConsistency ==
    futureState = "callback-error" => ~callbackAlive

=============================================================================
