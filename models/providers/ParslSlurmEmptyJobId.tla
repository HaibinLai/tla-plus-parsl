--------------------------- MODULE ParslSlurmEmptyJobId ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Slurm's default submit regex uses ``\\S*`` for the captured job ID.  A
 * successful-looking line with no identifier can therefore match and publish
 * an empty-string resource key.  USE_FIXED requires a non-empty identifier.
 ***************************************************************************)

CONSTANT USE_FIXED
VARIABLES state, jobId
vars == <<state, jobId>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ state = "waiting"
    /\ jobId = "unset"

ProcessResponse ==
    /\ state = "waiting"
    /\ state' = IF USE_FIXED THEN "rejected" ELSE "submitted"
    /\ jobId' = IF USE_FIXED THEN "unset" ELSE ""

Next == ProcessResponse \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in {"waiting", "submitted", "rejected"}
    /\ jobId \in {"unset", ""}

JobIdSafety == state = "submitted" => jobId # ""
=============================================================================
