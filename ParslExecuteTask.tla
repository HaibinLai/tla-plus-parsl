--------------------------- MODULE ParslExecuteTask ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Small model of executors.execute_task: decode one packed apply message,
 * invoke the reconstructed callable, and return either a value or an error.
 * A malformed message must be rejected before user code runs.
 ***************************************************************************)

CONSTANT PAYLOAD_KIND, FUNCTION_OUTCOME

PayloadKinds == {"valid", "malformed"}
Outcomes == {"value", "exception"}
ExecutionStates == {"wire", "decoded", "running", "succeeded", "failed", "rejected"}
ResultStates == {"none", "value", "exception"}
VARIABLES executionState, resultState, invoked
vars == <<executionState, resultState, invoked>>

Init ==
    /\ PAYLOAD_KIND \in PayloadKinds
    /\ FUNCTION_OUTCOME \in Outcomes
    /\ executionState = "wire"
    /\ resultState = "none"
    /\ invoked = FALSE

Decode ==
    /\ executionState = "wire"
    /\ IF PAYLOAD_KIND = "valid"
          THEN executionState' = "decoded"
          ELSE executionState' = "rejected"
    /\ UNCHANGED <<resultState, invoked>>

Invoke ==
    /\ executionState = "decoded"
    /\ executionState' = "running"
    /\ invoked' = TRUE
    /\ UNCHANGED resultState

ReturnValue ==
    /\ executionState = "running"
    /\ FUNCTION_OUTCOME = "value"
    /\ executionState' = "succeeded"
    /\ resultState' = "value"
    /\ UNCHANGED invoked

RaiseException ==
    /\ executionState = "running"
    /\ FUNCTION_OUTCOME = "exception"
    /\ executionState' = "failed"
    /\ resultState' = "exception"
    /\ UNCHANGED invoked

Next ==
    \/ Decode
    \/ Invoke
    \/ ReturnValue
    \/ RaiseException
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ executionState \in ExecutionStates
    /\ resultState \in ResultStates
    /\ invoked \in BOOLEAN

DecodeSafety ==
    executionState = "rejected" =>
        /\ PAYLOAD_KIND = "malformed"
        /\ ~invoked
        /\ resultState = "none"

ResultSafety ==
    /\ executionState = "succeeded" => resultState = "value"
    /\ executionState = "failed" => resultState = "exception"

=============================================================================
