--------------------------- MODULE ParslJoinRunningCancellation ---------------------------
EXTENDS Naturals

(***************************************************************************
 * A focused join_app race: the inner Future is already running when it is
 * cancelled, and its callback observes CancelledError.
 *
 * The current branch lets that callback exception escape and leaves the outer
 * join pending. The fixed branch converts cancellation into terminal failure.
 **************************************************************************)

CONSTANT USE_FIXED

InnerStates == {"pending", "running", "cancelled", "succeeded"}
OuterStates == {"joining", "succeeded", "failed"}

VARIABLES inner, outer, callbackPending, callbackRaised, handled
vars == <<inner, outer, callbackPending, callbackRaised, handled>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ inner = "pending"
    /\ outer = "joining"
    /\ callbackPending = FALSE
    /\ callbackRaised = FALSE
    /\ handled = FALSE

StartInner ==
    /\ inner = "pending"
    /\ inner' = "running"
    /\ UNCHANGED <<outer, callbackPending, callbackRaised, handled>>

CancelRunningInner ==
    /\ inner = "running"
    /\ inner' = "cancelled"
    /\ callbackPending' = TRUE
    /\ UNCHANGED <<outer, callbackRaised, handled>>

CompleteInner ==
    /\ inner = "running"
    /\ inner' = "succeeded"
    /\ callbackPending' = TRUE
    /\ UNCHANGED <<outer, callbackRaised, handled>>

HandleCallback ==
    /\ callbackPending
    /\ callbackPending' = FALSE
    /\ handled' = TRUE
    /\ IF inner = "cancelled"
       THEN IF USE_FIXED
            THEN /\ outer' = "failed"
                 /\ callbackRaised' = FALSE
            ELSE /\ outer' = outer
                 /\ callbackRaised' = TRUE
       ELSE /\ outer' = "succeeded"
            /\ callbackRaised' = FALSE
    /\ UNCHANGED inner

Next ==
    \/ StartInner
    \/ CancelRunningInner
    \/ CompleteInner
    \/ HandleCallback
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ inner \in InnerStates
    /\ outer \in OuterStates
    /\ callbackPending \in BOOLEAN
    /\ callbackRaised \in BOOLEAN
    /\ handled \in BOOLEAN

RunningCancellationIsTerminal ==
    handled /\ inner = "cancelled" => outer = "failed"

NoCallbackEscape ==
    handled => ~callbackRaised

=============================================================================
