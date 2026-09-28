--------------------------- MODULE ParslTorqueCancel ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Torque cancellation state convention.
 *
 * TorqueProvider.cancel returns True after qdel succeeds but records the
 * resource as COMPLETED (the source comment calls this "exiting").  This
 * focused model contrasts that convention with a stricter CANCELLED state.
 ***************************************************************************)

CONSTANTS API_SUCCESS, USE_FIXED

States == {"running", "completed", "cancelled"}

VARIABLES resourceState, cancelResult
vars == <<resourceState, cancelResult>>

Init ==
    /\ API_SUCCESS \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ resourceState = "running"
    /\ cancelResult = "none"

CancelSuccess ==
    /\ resourceState = "running"
    /\ API_SUCCESS
    /\ cancelResult' = "success"
    /\ resourceState' = IF USE_FIXED THEN "cancelled" ELSE "completed"

CancelFailure ==
    /\ resourceState = "running"
    /\ ~API_SUCCESS
    /\ cancelResult' = "failure"
    /\ UNCHANGED resourceState

Next ==
    \/ CancelSuccess
    \/ CancelFailure
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ resourceState \in States
    /\ cancelResult \in {"none", "success", "failure"}

StrictCancellation ==
    cancelResult = "success" => resourceState = "cancelled"

FailurePreservesRunning ==
    cancelResult = "failure" => resourceState = "running"

=============================================================================
