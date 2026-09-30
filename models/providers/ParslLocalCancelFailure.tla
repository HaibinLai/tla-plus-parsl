--------------------------- MODULE ParslLocalCancelFailure ---------------------------
EXTENDS Naturals

(***************************************************************************
 * LocalProvider.cancel result contract.
 *
 * A failed local kill command must not be reported as successful cancellation
 * while the resource remains running.  The current branch returns TRUE for
 * every requested ID regardless of the command result; USE_FIXED reports a
 * failure and preserves the running resource.
 ***************************************************************************)

CONSTANTS KILL_SUCCEEDS, USE_FIXED

ResourceStates == {"running", "cancelled"}
ResultStates == {"none", "success", "failure"}

VARIABLES resource, result
vars == <<resource, result>>

Init ==
    /\ KILL_SUCCEEDS \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ resource = "running"
    /\ result = "none"

Cancel ==
    /\ resource = "running"
    /\ IF KILL_SUCCEEDS
       THEN /\ resource' = "cancelled"
            /\ result' = "success"
       ELSE IF USE_FIXED
            THEN /\ resource' = "running"
                 /\ result' = "failure"
            ELSE /\ resource' = "running"
                 /\ result' = "success"

Next ==
    \/ Cancel
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ KILL_SUCCEEDS \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ resource \in ResourceStates
    /\ result \in ResultStates

CancellationResultSafety ==
    /\ result = "success" => resource = "cancelled"
    /\ result = "failure" => resource = "running"

=============================================================================
