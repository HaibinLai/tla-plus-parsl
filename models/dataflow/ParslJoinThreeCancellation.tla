----------------------- MODULE ParslJoinThreeCancellation -----------------------
EXTENDS Naturals, FiniteSets

(***************************************************************************
 * Cancellation in a three-element list-valued join_app.
 *
 * The callback inspects every terminal inner Future.  Python's
 * Future.exception() raises CancelledError for a cancelled Future; the current
 * path lets that exception escape, while the fixed path converts cancellation
 * into terminal outer failure.
 ***************************************************************************)

CONSTANTS CANCEL_ID, USE_FIXED
INNER == {"I1", "I2", "I3"}
InnerStates == {"succeeded", "cancelled"}

VARIABLES outerState, innerState, observed, callbackRaised, handled
vars == <<outerState, innerState, observed, callbackRaised, handled>>

Init ==
    /\ CANCEL_ID \in INNER
    /\ USE_FIXED \in BOOLEAN
    /\ outerState = "joining"
    /\ innerState = [i \in INNER |->
          IF i = CANCEL_ID THEN "cancelled" ELSE "succeeded"]
    /\ observed = FALSE
    /\ callbackRaised = FALSE
    /\ handled = FALSE

HandleJoin ==
    /\ outerState = "joining"
    /\ ~observed
    /\ observed' = TRUE
    /\ IF USE_FIXED
          THEN /\ outerState' = "failed"
               /\ callbackRaised' = FALSE
               /\ handled' = TRUE
          ELSE /\ outerState' = "joining"
               /\ callbackRaised' = TRUE
               /\ handled' = FALSE
    /\ UNCHANGED innerState

Next == HandleJoin \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ outerState \in {"joining", "failed"}
    /\ innerState \in [INNER -> InnerStates]
    /\ observed \in BOOLEAN
    /\ callbackRaised \in BOOLEAN
    /\ handled \in BOOLEAN

CancellationTerminal == observed => outerState = "failed"
NoUnexpectedCallbackException == observed => ~callbackRaised
HandledSafety == handled => outerState = "failed"

=============================================================================
