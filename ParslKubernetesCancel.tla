--------------------------- MODULE ParslKubernetesCancel ---------------------------
EXTENDS Naturals

(***************************************************************************
 * KubernetesProvider.cancel boundary.
 *
 * The current implementation lets delete_namespaced_pod raise, but when the
 * delete call returns it unconditionally records CANCELLED and returns True.
 * This model distinguishes an accepted response, an exception, and a
 * returned-but-rejected response. The last case exposes the unchecked API
 * response boundary.
 ***************************************************************************)

CONSTANTS FIXED

ApiResults == {"success", "returned_error", "exception"}
ResourceStates == {"running", "cancelled"}
CancelResults == {"none", "success", "failure"}

VARIABLES apiResult, resourceState, cancelResult
vars == <<apiResult, resourceState, cancelResult>>

Init ==
    /\ FIXED \in BOOLEAN
    /\ apiResult = "none"
    /\ resourceState = "running"
    /\ cancelResult = "none"

ChooseApiResult(result) ==
    /\ apiResult = "none"
    /\ result \in ApiResults
    /\ apiResult' = result
    /\ UNCHANGED <<resourceState, cancelResult>>

Cancel ==
    /\ apiResult \in ApiResults
    /\ cancelResult = "none"
    /\ apiResult' = apiResult
    /\ IF apiResult = "exception" THEN
          /\ cancelResult' = "none"
          /\ resourceState' = "running"
       ELSE IF apiResult = "success" THEN
          /\ cancelResult' = "success"
          /\ resourceState' = "cancelled"
       ELSE IF FIXED THEN
          /\ cancelResult' = "failure"
          /\ resourceState' = "running"
       ELSE
          /\ cancelResult' = "success"
          /\ resourceState' = "cancelled"

Next ==
    \/ \E result \in ApiResults : ChooseApiResult(result)
    \/ Cancel
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ apiResult \in (ApiResults \cup {"none"})
    /\ resourceState \in ResourceStates
    /\ cancelResult \in CancelResults

FailurePreservesRunning ==
    cancelResult = "failure" => resourceState = "running"

SuccessCancels ==
    cancelResult = "success" => resourceState = "cancelled"

ReturnedErrorIsFailure ==
    (apiResult = "returned_error" /\ cancelResult # "none")
        => cancelResult = "failure" /\ resourceState = "running"

=============================================================================
