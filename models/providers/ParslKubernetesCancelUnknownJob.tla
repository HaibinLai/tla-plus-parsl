--------------------------- MODULE ParslKubernetesCancelUnknownJob ---------------------------
EXTENDS Naturals

(***************************************************************************
 * KubernetesProvider.cancel and a stale local job id.
 *
 * Cancellation can race with resource cleanup.  The current implementation
 * resolves the pod name through resources[job_id] and raises KeyError when
 * that entry is gone.  USE_FIXED represents a non-throwing stale cancel.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES state, returned, resourcePresent
vars == <<state, returned, resourcePresent>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ state = "active"
    /\ returned = "none"
    /\ resourcePresent = TRUE

Cleanup ==
    /\ state = "active"
    /\ state' = "cleaned"
    /\ resourcePresent' = FALSE
    /\ UNCHANGED returned

Cancel ==
    /\ state = "cleaned"
    /\ state' = IF USE_FIXED THEN "ignored" ELSE "crashed"
    /\ returned' = IF USE_FIXED THEN "false" ELSE "none"
    /\ UNCHANGED resourcePresent

Next == Cleanup \/ Cancel \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ state \in {"active", "cleaned", "ignored", "crashed"}
    /\ returned \in {"none", "false"}
    /\ resourcePresent \in BOOLEAN

CleanupBoundary == state = "cleaned" => ~resourcePresent

CancelDoesNotCrash == state # "crashed"

=============================================================================
