--------------------------- MODULE ParslGlobusComputeResult ---------------------------
EXTENDS Naturals

(***************************************************************************
 * GlobusComputeExecutor.submit returns the Future created by the underlying
 * Globus Compute SDK.  Parsl therefore observes the SDK Future's terminal
 * success, exception, or cancellation directly; no wrapper result state is
 * introduced by this executor.
 *************************************************************************** *)

VARIABLES phase, sdkResult, parslResult
vars == <<phase, sdkResult, parslResult>>

Init ==
    /\ phase = "idle"
    /\ sdkResult = "none"
    /\ parslResult = "none"

Submit ==
    /\ phase = "idle"
    /\ phase' = "submitted"
    /\ sdkResult' = "pending"
    /\ parslResult' = "pending"

CompleteSuccess ==
    /\ phase = "submitted"
    /\ phase' = "terminal"
    /\ sdkResult' = "success"
    /\ parslResult' = "success"

CompleteFailure ==
    /\ phase = "submitted"
    /\ phase' = "terminal"
    /\ sdkResult' = "failure"
    /\ parslResult' = "failure"

Cancel ==
    /\ phase = "submitted"
    /\ phase' = "terminal"
    /\ sdkResult' = "cancelled"
    /\ parslResult' = "cancelled"

Done ==
    /\ phase = "terminal"
    /\ UNCHANGED vars

Next == Submit \/ CompleteSuccess \/ CompleteFailure \/ Cancel \/ Done
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ phase \in {"idle", "submitted", "terminal"}
    /\ sdkResult \in {"none", "pending", "success", "failure", "cancelled"}
    /\ parslResult \in {"none", "pending", "success", "failure", "cancelled"}

ResultPropagation == parslResult = sdkResult
TerminalStability == phase = "terminal" => parslResult \in {"success", "failure", "cancelled"}

=============================================================================
