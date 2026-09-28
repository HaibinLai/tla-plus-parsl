--------------------------- MODULE ParslRadicalPilotFailurePayload ---------------------------
EXTENDS Naturals

(***************************************************************************
 * RadicalPilotExecutor.task_state_cb failure payload handling.
 *
 * For a failed non-executable task, the current callback passes a string to
 * Future.set_exception when RADICAL-Pilot supplies no serialized exception.
 * concurrent.futures rejects that non-BaseException value with TypeError.
 * USE_FIXED represents wrapping the missing payload in RuntimeError first.
 ***************************************************************************)

CONSTANTS MISSING_EXCEPTION, USE_FIXED

States == {"running", "failed", "callback_error"}
FutureStates == {"pending", "failed", "callback_error"}

VARIABLES taskState, futureState
vars == <<taskState, futureState>>

Init ==
    /\ MISSING_EXCEPTION \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ taskState = "running"
    /\ futureState = "pending"

FailureCallback ==
    /\ taskState = "running"
    /\ taskState' = "failed"
    /\ IF MISSING_EXCEPTION /\ ~USE_FIXED
          THEN futureState' = "callback_error"
          ELSE futureState' = "failed"

Next ==
    \/ FailureCallback
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ MISSING_EXCEPTION \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ taskState \in States
    /\ futureState \in FutureStates

FailureSafety ==
    taskState = "failed" => futureState = "failed"

=============================================================================
