--------------------------- MODULE ParslJoinImmediateCancellation ---------------------------
EXTENDS Naturals

(***************************************************************************
 * A cancelled inner Future can already be terminal when join_app registers
 * its callback.  concurrent.futures invokes add_done_callback immediately in
 * that case.  Future.exception() raises CancelledError; the current callback
 * therefore escapes before the outer Future is finalized.  USE_FIXED maps the
 * immediate cancellation to a terminal outer failure.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES state, callbackInvoked, callbackRaised
vars == <<state, callbackInvoked, callbackRaised>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ state = "joining"
    /\ callbackInvoked = FALSE
    /\ callbackRaised = FALSE

ImmediateCancelledCallback ==
    /\ state = "joining"
    /\ callbackInvoked = FALSE
    /\ callbackInvoked' = TRUE
    /\ IF USE_FIXED
          THEN /\ state' = "failed"
               /\ callbackRaised' = FALSE
          ELSE /\ state' = "joining"
               /\ callbackRaised' = TRUE

Next == ImmediateCancelledCallback \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in {"joining", "failed"}
    /\ callbackInvoked \in BOOLEAN
    /\ callbackRaised \in BOOLEAN

ImmediateCancellationSafety ==
    callbackInvoked => state = "failed"

NoEscapedCallback ==
    callbackInvoked => ~callbackRaised

=============================================================================
