--------------------------- MODULE ParslFluxResult ---------------------------
EXTENDS Naturals, FiniteSets

(***************************************************************************
 * A focused FluxExecutor result/cancellation model.
 *
 * FluxExecutor wraps a flux.job future and completes the Parsl-facing Future
 * from the result file.  A zero return code still requires a readable,
 * deserializable result file; nonzero return codes and result exceptions fail
 * the wrapper.  The current callback returns immediately when the underlying
 * Flux future is cancelled.  USE_FIXED models the candidate hardening that
 * propagates that cancellation to the wrapper Future.
 ***************************************************************************)

CONSTANT USE_FIXED

FluxStates == {"not_submitted", "running", "succeeded", "failed", "cancelled"}
WrapperStates == {"pending", "running", "succeeded", "failed", "cancelled"}
ResultKinds == {"none", "valid", "missing", "malformed", "task_exception"}

VARIABLES executorUp, fluxState, wrapperState, resultKind, callbackPending
vars == <<executorUp, fluxState, wrapperState, resultKind, callbackPending>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ executorUp = TRUE
    /\ fluxState = "not_submitted"
    /\ wrapperState = "pending"
    /\ resultKind = "none"
    /\ callbackPending = FALSE

Submit ==
    /\ executorUp
    /\ fluxState = "not_submitted"
    /\ wrapperState = "pending"
    /\ fluxState' = "running"
    /\ wrapperState' = "running"
    /\ UNCHANGED <<executorUp, resultKind, callbackPending>>

FluxSucceeds ==
    /\ fluxState = "running"
    /\ fluxState' = "succeeded"
    /\ callbackPending' = TRUE
    /\ UNCHANGED <<executorUp, wrapperState, resultKind>>

FluxFails ==
    /\ fluxState = "running"
    /\ fluxState' = "failed"
    /\ wrapperState' = "failed"
    /\ UNCHANGED <<executorUp, resultKind, callbackPending>>

FluxCancels ==
    /\ fluxState = "running"
    /\ fluxState' = "cancelled"
    /\ IF USE_FIXED THEN wrapperState' = "cancelled" ELSE wrapperState' = wrapperState
    /\ UNCHANGED <<executorUp, resultKind, callbackPending>>

PrepareResult(kind) ==
    /\ fluxState = "succeeded"
    /\ callbackPending
    /\ resultKind = "none"
    /\ kind \in {"valid", "missing", "malformed", "task_exception"}
    /\ resultKind' = kind
    /\ UNCHANGED <<executorUp, fluxState, wrapperState, callbackPending>>

CompleteCallback ==
    /\ fluxState = "succeeded"
    /\ callbackPending
    /\ resultKind \in {"valid", "missing", "malformed", "task_exception"}
    /\ wrapperState' =
          IF resultKind = "valid" THEN "succeeded" ELSE "failed"
    /\ callbackPending' = FALSE
    /\ UNCHANGED <<executorUp, fluxState, resultKind>>

Shutdown ==
    /\ executorUp
    /\ executorUp' = FALSE
    /\ UNCHANGED <<fluxState, wrapperState, resultKind, callbackPending>>

Next ==
    \/ Submit
    \/ FluxSucceeds
    \/ FluxFails
    \/ FluxCancels
    \/ \E kind \in {"valid", "missing", "malformed", "task_exception"} : PrepareResult(kind)
    \/ CompleteCallback
    \/ Shutdown
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ executorUp \in BOOLEAN
    /\ fluxState \in FluxStates
    /\ wrapperState \in WrapperStates
    /\ resultKind \in ResultKinds
    /\ callbackPending \in BOOLEAN

TerminalConsistency ==
    wrapperState = "succeeded" => fluxState = "succeeded" /\ resultKind = "valid"

ResultCompletionSafety ==
    wrapperState \in {"succeeded", "failed"} => ~callbackPending

CancellationPropagation ==
    fluxState = "cancelled" => wrapperState = "cancelled"

=============================================================================
