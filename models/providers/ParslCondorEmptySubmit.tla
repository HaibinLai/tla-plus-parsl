--------------------------- MODULE ParslCondorEmptySubmit ---------------------------
EXTENDS Naturals

(***************************************************************************
 * CondorProvider.submit assumes that a successful condor_submit response
 * contains at least one matching job line.  With empty stdout the current
 * path indexes job_id[0] and leaks IndexError instead of returning an
 * explicit failed submission.  USE_FIXED models validating the parsed list
 * before indexing it.
 ***************************************************************************)

CONSTANT USE_FIXED
VARIABLES state, jobIdPresent
vars == <<state, jobIdPresent>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ state = "waiting"
    /\ jobIdPresent = FALSE

ProcessEmptyResponse ==
    /\ state = "waiting"
    /\ state' = IF USE_FIXED THEN "rejected" ELSE "raw-error"
    /\ UNCHANGED jobIdPresent

Next == ProcessEmptyResponse \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in {"waiting", "raw-error", "rejected"}
    /\ jobIdPresent \in BOOLEAN

NoRawEmptyResponse == state # "raw-error"

=============================================================================
