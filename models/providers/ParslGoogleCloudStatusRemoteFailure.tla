--------------------------- MODULE ParslGoogleCloudStatusRemoteFailure ---------------------------
EXTENDS Naturals

(***************************************************************************
 * GoogleCloudProvider.status performs one API request per requested VM but
 * does not isolate a request failure.  A transient or not-found error for
 * one VM therefore aborts the whole batch and hides later observations.
 * USE_FIXED models returning UNKNOWN for the failed VM and continuing.
 ***************************************************************************)

CONSTANT REMOTE_RESULT, USE_FIXED
VARIABLES phase, failed_status, healthy_status, outcome
vars == <<phase, failed_status, healthy_status, outcome>>

Init ==
    /\ REMOTE_RESULT \in {"ok", "missing"}
    /\ USE_FIXED \in BOOLEAN
    /\ phase = "query"
    /\ failed_status = "running"
    /\ healthy_status = "running"
    /\ outcome = "waiting"

HandleRemote ==
    /\ phase = "query"
    /\ REMOTE_RESULT = "missing"
    /\ phase' = "complete"
    /\ failed_status' = IF USE_FIXED THEN "unknown" ELSE failed_status
    /\ healthy_status' = IF USE_FIXED THEN "running" ELSE "unobserved"
    /\ outcome' = IF USE_FIXED THEN "isolated" ELSE "crash"

HandleOK ==
    /\ phase = "query"
    /\ REMOTE_RESULT = "ok"
    /\ phase' = "complete"
    /\ failed_status' = "running"
    /\ healthy_status' = "running"
    /\ outcome' = "complete"

Next == HandleRemote \/ HandleOK \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ phase \in {"query", "complete"}
    /\ failed_status \in {"running", "unknown"}
    /\ healthy_status \in {"running", "unobserved"}
    /\ outcome \in {"waiting", "isolated", "complete", "crash"}

StatusBatchSafety == phase = "complete" => outcome # "crash"
HealthyObservationPreserved ==
    phase = "complete" /\ REMOTE_RESULT = "missing" /\ USE_FIXED
        => healthy_status = "running"
=============================================================================
