--------------------------- MODULE ParslFluxLateResultCancelledFuture ---------------------------
EXTENDS Naturals

(***************************************************************************
 * A Flux completion callback can arrive after the user-facing wrapper was
 * cancelled.  The current callback writes a result into that terminal
 * Future, raising InvalidStateError; USE_FIXED ignores the stale callback.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES wrapperState, callbackRaised
vars == <<wrapperState, callbackRaised>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ wrapperState = "cancelled"
    /\ callbackRaised = FALSE

LateResult ==
    /\ wrapperState = "cancelled"
    /\ callbackRaised' = IF USE_FIXED THEN FALSE ELSE TRUE
    /\ UNCHANGED wrapperState

Next == LateResult \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ wrapperState = "cancelled"
    /\ callbackRaised \in BOOLEAN

StaleResultSafety ==
    ~callbackRaised

=============================================================================
