--------------------------- MODULE ParslFluxCancelRunningRace ---------------------------
EXTENDS Naturals

(***************************************************************************
 * FluxFutureWrapper.cancel can race with wrapper execution state.  If the
 * underlying Flux future still accepts cancellation while the Parsl wrapper
 * is already RUNNING, the current code cancels the underlying future and then
 * raises RuntimeError when Future.cancel() returns False.  USE_FIXED models
 * rejecting the request before changing the underlying state.
 *************************************************************************** *)

CONSTANT USE_FIXED

VARIABLES fluxState, wrapperState, outcome
vars == <<fluxState, wrapperState, outcome>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ fluxState = "running"
    /\ wrapperState = "running"
    /\ outcome = "none"

Cancel ==
    /\ fluxState = "running"
    /\ wrapperState = "running"
    /\ fluxState' = IF USE_FIXED THEN "running" ELSE "cancelled"
    /\ wrapperState' = "running"
    /\ outcome' = IF USE_FIXED THEN "rejected" ELSE "runtime-error"

Done ==
    /\ outcome # "none"
    /\ UNCHANGED vars

Next == Cancel \/ Done
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ fluxState \in {"running", "cancelled"}
    /\ wrapperState = "running"
    /\ outcome \in {"none", "rejected", "runtime-error"}

NoRawCancelError ==
    outcome # "runtime-error"

LayerConsistency ==
    outcome = "rejected" => fluxState = "running"

=============================================================================
