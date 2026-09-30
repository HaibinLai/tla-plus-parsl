--------------------------- MODULE ParslKubernetesCancelResponse ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Kubernetes pod cancellation response handling.
 *
 * The delete API can return a response object whose status reports failure.
 * The current provider treats any returned object as success; USE_FIXED only
 * marks the local resource cancelled after a successful delete response.
 ***************************************************************************)

CONSTANTS USE_FIXED, DELETE_SUCCEEDED

VARIABLES jobState, cancelResult
vars == <<jobState, cancelResult>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ DELETE_SUCCEEDED \in BOOLEAN
    /\ jobState = "running"
    /\ cancelResult = "pending"

Cancel ==
    /\ jobState = "running"
    /\ cancelResult' = IF DELETE_SUCCEEDED THEN "success" ELSE "failure"
    /\ jobState' = IF DELETE_SUCCEEDED \/ ~USE_FIXED
                      THEN "cancelled" ELSE "running"

Next == Cancel \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ DELETE_SUCCEEDED \in BOOLEAN
    /\ jobState \in {"running", "cancelled"}
    /\ cancelResult \in {"pending", "success", "failure"}

DeleteFailureSafety ==
    cancelResult = "failure" => jobState = "running"

=============================================================================
