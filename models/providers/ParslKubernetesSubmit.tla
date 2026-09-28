--------------------------- MODULE ParslKubernetesSubmit ---------------------------
EXTENDS Naturals

(***************************************************************************
 * KubernetesProvider.submit boundary.
 *
 * submit() creates a pod through the API and then records the resource.  The
 * current source records JobState.RUNNING immediately after create_pod,
 * although the pod can still be Pending.  This model keeps API creation
 * abstract and checks the post-submit admission state.
 ***************************************************************************)

CONSTANTS FIXED

ApiResults == {"success", "error"}
ResourceStates == {"none", "pending", "running", "submit_error"}

VARIABLES apiResult, resourceState
vars == <<apiResult, resourceState>>

Init ==
    /\ FIXED \in BOOLEAN
    /\ apiResult = "none"
    /\ resourceState = "none"

ChooseApiResult(result) ==
    /\ apiResult = "none"
    /\ result \in ApiResults
    /\ apiResult' = result
    /\ UNCHANGED resourceState

Submit ==
    /\ apiResult \in ApiResults
    /\ resourceState = "none"
    /\ apiResult' = apiResult
    /\ resourceState' =
          IF apiResult = "error" THEN "submit_error"
          ELSE IF FIXED THEN "pending" ELSE "running"

Next ==
    \/ \E result \in ApiResults : ChooseApiResult(result)
    \/ Submit
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ apiResult \in (ApiResults \cup {"none"})
    /\ resourceState \in ResourceStates

CreationFailureIsNotResource ==
    resourceState = "submit_error" => apiResult = "error"

SubmitStatePending ==
    resourceState = "running" => FALSE

=============================================================================
