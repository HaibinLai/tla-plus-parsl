--------------------------- MODULE ParslFluxCancelSubmitRace ---------------------------
EXTENDS Naturals

(***************************************************************************
 * FluxFutureWrapper cancellation versus late underlying-future binding.
 *
 * cancel() can observe _flux_future == None before the submission thread binds
 * the real Flux future.  The current path cancels the wrapper, then a later
 * successful callback attempts set_result on that cancelled wrapper.  USE_FIXED
 * models carrying the cancellation request into the bind step and suppressing
 * the late callback.
 ***************************************************************************)

CONSTANT USE_FIXED

WrapperStates == {"pending", "cancelled", "succeeded"}
FluxStates == {"unbound", "running", "cancelled", "succeeded"}
CallbackStates == {"idle", "attempted", "suppressed", "published", "error"}

VARIABLES wrapper, flux, callback, cancelRequested
vars == <<wrapper, flux, callback, cancelRequested>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ wrapper = "pending"
    /\ flux = "unbound"
    /\ callback = "idle"
    /\ cancelRequested = FALSE

CancelBeforeBind ==
    /\ wrapper = "pending"
    /\ flux = "unbound"
    /\ wrapper' = "cancelled"
    /\ cancelRequested' = TRUE
    /\ UNCHANGED <<flux, callback>>

BindUnderlying ==
    /\ flux = "unbound"
    /\ flux' = IF (USE_FIXED /\ cancelRequested)
                  THEN "cancelled"
                  ELSE "running"
    /\ UNCHANGED <<wrapper, callback, cancelRequested>>

CompleteUnderlying ==
    /\ flux = "running"
    /\ flux' = "succeeded"
    /\ callback' = "attempted"
    /\ UNCHANGED <<wrapper, cancelRequested>>

PublishCallback ==
    /\ callback = "attempted"
    /\ flux = "succeeded"
    /\ IF wrapper = "cancelled"
          THEN /\ callback' = "error"
               /\ UNCHANGED wrapper
          ELSE /\ callback' = "published"
               /\ wrapper' = "succeeded"
    /\ UNCHANGED <<flux, cancelRequested>>

SuppressCancelledCallback ==
    /\ USE_FIXED
    /\ flux = "cancelled"
    /\ callback' = "suppressed"
    /\ UNCHANGED <<wrapper, flux, cancelRequested>>

Next ==
    \/ CancelBeforeBind
    \/ BindUnderlying
    \/ CompleteUnderlying
    \/ PublishCallback
    \/ SuppressCancelledCallback
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ wrapper \in WrapperStates
    /\ flux \in FluxStates
    /\ callback \in CallbackStates
    /\ cancelRequested \in BOOLEAN

NoLateCallbackError ==
    wrapper = "cancelled" => callback # "error"

NoLatePublication ==
    wrapper = "cancelled" => callback # "published"

=============================================================================
SPECIFICATION Spec

INVARIANTS
    TypeOK
    NoLateCallbackError
    NoLatePublication
