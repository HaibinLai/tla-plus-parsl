--------------------------- MODULE ParslPbsproSubmitShape ---------------------------
EXTENDS Naturals, Sequences

(***************************************************************************
 * PBSPro submit should publish one scheduler job for one qsub invocation.
 * The current implementation records every non-empty stdout line and returns
 * the last line as the job ID.  USE_FIXED accepts exactly the first non-empty
 * scheduler ID and rejects an ambiguous multi-line response.
 ***************************************************************************)

CONSTANT RESPONSE_KIND, USE_FIXED
VARIABLES phase, resourceCount, returned, outcome
vars == <<phase, resourceCount, returned, outcome>>

Init ==
    /\ RESPONSE_KIND \in {"single", "multiple", "empty"}
    /\ USE_FIXED \in BOOLEAN
    /\ phase = "submitted"
    /\ resourceCount = 0
    /\ returned = "none"
    /\ outcome = "waiting"

HandleResponse ==
    /\ phase = "submitted"
    /\ phase' = "complete"
    /\ IF RESPONSE_KIND = "single" THEN
           /\ resourceCount' = 1
           /\ returned' = "job-1"
           /\ outcome' = "published"
       ELSE IF RESPONSE_KIND = "multiple" THEN
           /\ resourceCount' = IF USE_FIXED THEN 0 ELSE 2
           /\ returned' = IF USE_FIXED THEN "none" ELSE "warning"
           /\ outcome' = IF USE_FIXED THEN "rejected" ELSE "ambiguous"
       ELSE
           /\ resourceCount' = 0
           /\ returned' = "none"
           /\ outcome' = "rejected"

Next == HandleResponse \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ phase \in {"submitted", "complete"}
    /\ resourceCount \in 0..2
    /\ returned \in {"none", "job-1", "warning"}
    /\ outcome \in {"waiting", "published", "ambiguous", "rejected"}

SubmitShapeSafety ==
    phase = "complete" => resourceCount <= 1
=============================================================================
