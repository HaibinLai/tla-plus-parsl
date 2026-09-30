--------------------------- MODULE ParslCondorSubmitCount ---------------------------
EXTENDS Naturals

(***************************************************************************
 * CondorProvider.submit parsing of a multi-digit job count.
 *
 * condor_submit reports the number of jobs as the first token in a line such
 * as "10 job(s) submitted ...".  The current implementation indexes the
 * string with line[0], so a count of ten is parsed as one.  The fixed branch
 * parses the complete token before expanding process IDs.
 ***************************************************************************)

CONSTANTS JOB_COUNT, USE_FIXED

VARIABLES reportedCount, registeredCount, result
vars == <<reportedCount, registeredCount, result>>

Init ==
    /\ JOB_COUNT \in 1..20
    /\ USE_FIXED \in BOOLEAN
    /\ reportedCount = 0
    /\ registeredCount = 0
    /\ result = "ready"

Submit ==
    /\ reportedCount = 0
    /\ reportedCount' = JOB_COUNT
    /\ registeredCount' = IF USE_FIXED /\ JOB_COUNT >= 10
                              THEN JOB_COUNT
                              ELSE IF JOB_COUNT >= 10 THEN 1 ELSE JOB_COUNT
    /\ result' = "submitted"

Next == Submit \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ reportedCount \in 0..20
    /\ registeredCount \in 0..20
    /\ result \in {"ready", "submitted"}

CountSafety ==
    result = "submitted" => registeredCount = JOB_COUNT

=============================================================================
