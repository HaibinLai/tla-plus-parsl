--------------------------- MODULE ParslJoinSingleCancellation ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Cancellation in a single-Future join_app callback.
 *
 * Future.exception() raises CancelledError for a cancelled inner Future.  The
 * current handle_join_update lets that exception escape, leaving the outer
 * task in joining.  USE_FIXED maps cancellation to terminal JoinError-style
 * failure instead.
 ***************************************************************************)

CONSTANTS CANCELLED, USE_FIXED

VARIABLES state, observed, callbackRaised, cancellationHandled
vars == <<state, observed, callbackRaised, cancellationHandled>>

Init ==
    /\ CANCELLED \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ state = "joining"
    /\ observed = FALSE
    /\ callbackRaised = FALSE
    /\ cancellationHandled = FALSE

ObserveCancelled ==
    /\ state = "joining"
    /\ CANCELLED
    /\ observed' = TRUE
    /\ IF USE_FIXED
          THEN /\ state' = "failed"
               /\ callbackRaised' = FALSE
               /\ cancellationHandled' = TRUE
          ELSE /\ state' = "joining"
               /\ callbackRaised' = TRUE
               /\ cancellationHandled' = FALSE

ObserveSuccess ==
    /\ state = "joining"
    /\ ~CANCELLED
    /\ observed' = TRUE
    /\ state' = "completed"
    /\ callbackRaised' = FALSE
    /\ cancellationHandled' = FALSE

Next ==
    \/ ObserveCancelled
    \/ ObserveSuccess
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ CANCELLED \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ state \in {"joining", "completed", "failed"}
    /\ observed \in BOOLEAN
    /\ callbackRaised \in BOOLEAN
    /\ cancellationHandled \in BOOLEAN

CancellationTerminal ==
    observed /\ CANCELLED => state = "failed"

NoUnexpectedCallbackException ==
    observed => ~callbackRaised

=============================================================================
