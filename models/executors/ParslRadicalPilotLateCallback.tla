--------------------------- MODULE ParslRadicalPilotLateCallback ---------------------------
EXTENDS Naturals

(***************************************************************************
 * RadicalPilotExecutor.task_state_cb maps RP states directly onto a Parsl
 * Future.  A CANCELED callback can race with a late DONE callback.  The
 * current callback calls Future.set_result unconditionally, which raises
 * InvalidStateError on the canceled Future.  USE_FIXED discards callbacks
 * after a terminal Future state.
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

LateDone ==
    /\ rpState = "canceled"
    /\ rpState' = "canceled"
    /\ IF USE_FIXED
          THEN /\ futureState' = "cancelled"
               /\ callbackAlive' = TRUE
          ELSE /\ futureState' = "callback-error"
               /\ callbackAlive' = FALSE

NormalDone ==
    /\ rpState = "running"
    /\ rpState' = "done"
    /\ futureState' = "succeeded"
    /\ UNCHANGED callbackAlive

Done ==
    /\ rpState \in {"done", "canceled"}
    /\ UNCHANGED vars

Next == Cancel \/ LateDone \/ NormalDone \/ Done
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ rpState \in {"running", "done", "canceled"}
    /\ futureState \in {"pending", "succeeded", "cancelled", "callback-error"}
    /\ callbackAlive \in BOOLEAN

LateCallbackSafety ==
    rpState = "canceled" => callbackAlive

TerminalFutureConsistency ==
    futureState = "callback-error" => ~callbackAlive

=============================================================================
