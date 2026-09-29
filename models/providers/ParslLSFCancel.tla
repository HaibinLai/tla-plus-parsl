--------------------------- MODULE ParslLSFCancel ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Bounded model of LSFProvider.cancel.
 *
 * The current implementation treats a successful bkill as proof that every
 * requested id exists locally, then indexes resources[jid].  A scheduler
 * success for an unknown id therefore reaches a KeyError-like crash.  The
 * model keeps that boundary explicit so TLC can produce a short counterexample.
 ***************************************************************************)

CONSTANTS API_SUCCESS, JOB_PRESENT, USE_FIXED

States == {"running", "cancelled", "failed", "crashed"}

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
           /\ resourceState' = "cancelled"
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
    /\ cancelResult = "success" => resourceState = "cancelled"
    /\ cancelResult = "failure" => resourceState = "failed"

=============================================================================
