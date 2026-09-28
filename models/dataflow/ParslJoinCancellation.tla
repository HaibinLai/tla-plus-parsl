--------------------------- MODULE ParslJoinCancellation ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Bounded model of join_app observing a cancelled inner Future.
 *
 * Future.exception() raises CancelledError for a cancelled Future.  The
 * current join callback does not catch that exception, so callback execution
 * exits while the outer task remains joining.  USE_FIXED maps cancellation
 * into the ordinary JoinError failure path.
 ***************************************************************************)

CONSTANTS INNER_CANCELLED, USE_FIXED

InnerStates == {"pending", "succeeded", "cancelled"}
OuterStates == {"joining", "succeeded", "failed"}
CallbackStates == {"idle", "done", "crashed"}

VARIABLES innerState, outerState, callbackState
vars == <<innerState, outerState, callbackState>>

Init ==
    /\ INNER_CANCELLED \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ innerState = "pending"
    /\ outerState = "joining"
    /\ callbackState = "idle"

CompleteInner ==
    /\ innerState = "pending"
    /\ innerState' = IF INNER_CANCELLED THEN "cancelled" ELSE "succeeded"
    /\ UNCHANGED <<outerState, callbackState>>

HandleCallback ==
    /\ innerState \in {"succeeded", "cancelled"}
    /\ callbackState = "idle"
    /\ IF innerState = "succeeded" THEN
           /\ outerState' = "succeeded"
           /\ callbackState' = "done"
       ELSE IF USE_FIXED THEN
           /\ outerState' = "failed"
           /\ callbackState' = "done"
       ELSE
           /\ UNCHANGED outerState
           /\ callbackState' = "crashed"
    /\ UNCHANGED innerState

Next ==
    \/ CompleteInner
    \/ HandleCallback
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ innerState \in InnerStates
    /\ outerState \in OuterStates
    /\ callbackState \in CallbackStates

NoCallbackCrash == callbackState # "crashed"

CancelledJoinSafety ==
    innerState = "cancelled" /\ callbackState = "done" => outerState = "failed"

=============================================================================
