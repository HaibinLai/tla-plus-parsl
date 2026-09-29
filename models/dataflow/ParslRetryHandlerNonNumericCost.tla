--------------------------- MODULE ParslRetryHandlerNonNumericCost ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Retry-handler return-type validation.
 *
 * Config accepts any callable as retry_handler, but the result is added
 * directly to the numeric fail_cost.  A non-numeric result raises from the
 * execution callback.  The current path leaves the outer AppFuture pending;
 * the fixed path converts the invalid handler result into terminal failure.
 *************************************************************************** *)

CONSTANT USE_FIXED
VARIABLES state, futureState
vars == <<state, futureState>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ state = "attempt-failed"
    /\ futureState = "pending"

HandleInvalidCost ==
    /\ state = "attempt-failed"
    /\ IF USE_FIXED
          THEN /\ state' = "handler-failed"
               /\ futureState' = "failed"
          ELSE /\ state' = "callback-error"
               /\ futureState' = "pending"

Next == HandleInvalidCost \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in {"attempt-failed", "handler-failed", "callback-error"}
    /\ futureState \in {"pending", "failed"}

NoPendingAfterHandlerError == state = "callback-error" => USE_FIXED

=============================================================================
