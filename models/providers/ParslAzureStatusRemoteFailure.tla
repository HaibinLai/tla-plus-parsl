--------------------------- MODULE ParslAzureStatusRemoteFailure ---------------------------
EXTENDS Naturals

(***************************************************************************
 * AzureProvider.status does not catch cloud API failures from
 * virtual_machines.get.  A VM deleted or temporarily unavailable remotely
 * therefore aborts the entire status request, including unrelated jobs.
 * USE_FIXED models isolating that observation as UNKNOWN and continuing.
 ***************************************************************************)

CONSTANT REMOTE_RESULT, USE_FIXED
VARIABLES phase, known_status, other_status, outcome
vars == <<phase, known_status, other_status, outcome>>

Init ==
    /\ REMOTE_RESULT \in {"ok", "missing"}
    /\ USE_FIXED \in BOOLEAN
    /\ phase = "query"
    /\ known_status = "running"
    /\ other_status = "running"
    /\ outcome = "waiting"

HandleRemote ==
    /\ phase = "query"
    /\ REMOTE_RESULT = "missing"
    /\ phase' = "complete"
    /\ known_status' = IF USE_FIXED THEN "unknown" ELSE known_status
    /\ other_status' = IF USE_FIXED THEN "running" ELSE "unobserved"
    /\ outcome' = IF USE_FIXED THEN "isolated" ELSE "crash"

HandleOK ==
    /\ phase = "query"
    /\ REMOTE_RESULT = "ok"
    /\ phase' = "complete"
    /\ known_status' = "running"
    /\ other_status' = "running"
    /\ outcome' = "complete"

Next == HandleRemote \/ HandleOK \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ phase \in {"query", "complete"}
    /\ known_status \in {"running", "unknown"}
    /\ other_status \in {"running", "unobserved"}
    /\ outcome \in {"waiting", "isolated", "complete", "crash"}

StatusBatchSafety == phase = "complete" => outcome # "crash"
UnrelatedObservationPreserved ==
    phase = "complete" /\ REMOTE_RESULT = "missing" /\ USE_FIXED
        => other_status = "running"
=============================================================================
