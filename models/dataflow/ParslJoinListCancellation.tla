--------------------------- MODULE ParslJoinListCancellation ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Cancellation in the list-valued join_app callback.
 *
 * DataFlowKernel.handle_join_update checks that every Future in a join list
 * is done, then calls Future.exception() for each one.  Future.exception()
 * raises CancelledError for a cancelled Future, so the current callback
 * escapes without completing the outer task.  The FIXED branch converts the
 * cancellation into the same terminal failure protocol used for an ordinary
 * inner exception.
 *************************************************************************** *)

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
    /\ state \in {"joining", "completed", "failed"}
    /\ observed \in BOOLEAN
    /\ callbackRaised \in BOOLEAN
    /\ cancellationHandled \in BOOLEAN

CancellationTerminal ==
    observed /\ CANCELLED => state = "failed"

NoUnexpectedCallbackException ==
    observed => ~callbackRaised

=============================================================================
