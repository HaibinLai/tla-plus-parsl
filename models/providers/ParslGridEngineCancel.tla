--------------------------- MODULE ParslGridEngineCancel ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Bounded model of GridEngineProvider.cancel.
 *
 * qdel success is recorded as COMPLETED (the provider's exiting convention),
 * while a failed qdel leaves the resource unchanged.  As with the LSF path,
 * a successful cancellation of an id absent from the local resource map
 * reaches a direct dictionary lookup and can crash.
 ***************************************************************************)

CONSTANTS API_SUCCESS, JOB_PRESENT, USE_FIXED

States == {"running", "completed", "failed", "crashed"}

VARIABLES resourceState, cancelResult
vars == <<resourceState, cancelResult>>

Init ==
    /\ API_SUCCESS \in BOOLEAN
    /\ JOB_PRESENT \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ resourceState = "running"
    /\ cancelResult = "none"

Cancel ==
    /\ resourceState = "running"
    /\ IF ~API_SUCCESS THEN
           /\ resourceState' = "failed"
           /\ cancelResult' = "failure"
       ELSE IF JOB_PRESENT THEN
           /\ resourceState' = "completed"
           /\ cancelResult' = "success"
       ELSE IF USE_FIXED THEN
           /\ resourceState' = "running"
           /\ cancelResult' = "stale"
       ELSE
           /\ resourceState' = "crashed"
           /\ cancelResult' = "none"

Next ==
    \/ Cancel
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ resourceState \in States
    /\ cancelResult \in {"none", "success", "failure", "stale"}

NoUnknownIdCrash == resourceState # "crashed"

CancellationResultSafety ==
    /\ cancelResult = "success" => resourceState = "completed"
    /\ cancelResult = "failure" => resourceState = "failed"

=============================================================================
