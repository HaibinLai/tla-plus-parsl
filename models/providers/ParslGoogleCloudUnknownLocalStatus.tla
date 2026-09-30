--------------------------- MODULE ParslGoogleCloudUnknownLocalStatus ---------------------------
EXTENDS Naturals

(***************************************************************************
 * GoogleCloudProvider.status receives an instance observation from GCE and
 * then indexes local resources[job_id].  A stale local ID can therefore turn
 * an otherwise valid cloud response into a KeyError.  USE_FIXED treats the
 * observation as an UNKNOWN/stale result and keeps polling isolated.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES phase, localPresent, outcome
vars == <<phase, localPresent, outcome>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ phase = "queried"
    /\ localPresent = FALSE
    /\ outcome = "waiting"

ProjectCloudState ==
    /\ phase = "queried"
    /\ phase' = IF USE_FIXED THEN "complete" ELSE "crashed"
    /\ outcome' = IF USE_FIXED THEN "unknown" ELSE "exception"
    /\ UNCHANGED localPresent

Next == ProjectCloudState \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ phase \in {"queried", "complete", "crashed"}
    /\ localPresent \in BOOLEAN
    /\ outcome \in {"waiting", "unknown", "exception"}

StaleStatusSafety == phase # "crashed"

=============================================================================
