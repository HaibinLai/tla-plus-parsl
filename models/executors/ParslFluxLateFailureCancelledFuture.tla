--------------------------- MODULE ParslFluxLateFailureCancelledFuture ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Flux completion can race with cancellation of the Parsl-facing wrapper.
 * _complete_future checks the underlying Flux future, but not the wrapper,
 * before publishing an exception. A late failed job therefore calls
 * set_exception on a cancelled wrapper and raises InvalidStateError. The
 * fixed branch ignores terminal wrappers before publishing the failure.
 *************************************************************************** *)

CONSTANT USE_FIXED

VARIABLES wrapperState, fluxState, callbackAlive, callbackDone
vars == <<wrapperState, fluxState, callbackAlive, callbackDone>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ wrapperState = "cancelled"
    /\ fluxState = "failed"
    /\ callbackAlive = TRUE
    /\ callbackDone = FALSE

PublishFailure ==
    /\ callbackAlive
    /\ callbackAlive' = IF USE_FIXED THEN TRUE ELSE FALSE
    /\ callbackDone' = IF USE_FIXED THEN TRUE ELSE FALSE
    /\ UNCHANGED <<wrapperState, fluxState>>

Done ==
    /\ ~callbackAlive \/ callbackDone
    /\ UNCHANGED vars

Next == PublishFailure \/ Done
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ wrapperState = "cancelled"
    /\ fluxState = "failed"
    /\ callbackAlive \in BOOLEAN
    /\ callbackDone \in BOOLEAN

CancelledWrapperSafety ==
    wrapperState = "cancelled" => callbackAlive

FailureCallbackCompletion ==
    callbackDone => /\ wrapperState = "cancelled" /\ fluxState = "failed"

=============================================================================
