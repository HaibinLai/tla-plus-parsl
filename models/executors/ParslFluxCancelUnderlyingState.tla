--------------------------- MODULE ParslFluxCancelUnderlyingState ---------------------------
EXTENDS Naturals

(***************************************************************************
 * FluxFutureWrapper.cancel when the underlying Flux future is already
 * cancelled.
 *
 * The current implementation returns True immediately from the
 * ``_flux_future.cancelled()`` branch but does not cancel the Parsl-facing
 * wrapper.  USE_FIXED propagates the already-terminal cancellation state.
 *************************************************************************** *)

CONSTANT USE_FIXED

VARIABLES fluxState, wrapperState, cancelReturned
vars == <<fluxState, wrapperState, cancelReturned>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ fluxState = "cancelled"
    /\ wrapperState = "pending"
    /\ cancelReturned = FALSE

CancelWrapper ==
    /\ fluxState = "cancelled"
    /\ cancelReturned' = TRUE
    /\ wrapperState' = IF USE_FIXED THEN "cancelled" ELSE wrapperState
    /\ UNCHANGED fluxState

Next ==
    \/ CancelWrapper
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ fluxState = "cancelled"
    /\ wrapperState \in {"pending", "cancelled"}
    /\ cancelReturned \in BOOLEAN

CancellationConsistency ==
    cancelReturned => wrapperState = "cancelled"

=============================================================================
