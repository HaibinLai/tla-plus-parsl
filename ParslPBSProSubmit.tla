--------------------------- MODULE ParslPBSProSubmit ---------------------------
EXTENDS Naturals

(***************************************************************************
 * PBS Pro qsub submission boundary.
 *
 * Current PBSProProvider.submit accepts retcode == 0, scans stdout for a
 * non-empty line, and returns job_id.  With successful empty stdout it returns
 * None without adding a resource entry.  The model exposes that mismatch
 * between scheduler success and an executor-trackable job.
 ***************************************************************************)

CONSTANTS EMPTY_OUTPUT, USE_FIXED

States == {"ready", "submitted", "rejected"}

VARIABLES state, resourceRegistered, returnedJobId
vars == <<state, resourceRegistered, returnedJobId>>

Init ==
    /\ EMPTY_OUTPUT \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ state = "ready"
    /\ resourceRegistered = FALSE
    /\ returnedJobId = "none"

SubmitSuccess ==
    /\ state = "ready"
    /\ ~EMPTY_OUTPUT
    /\ state' = "submitted"
    /\ resourceRegistered' = TRUE
    /\ returnedJobId' = "job-1"

SubmitEmptyCurrent ==
    /\ state = "ready"
    /\ EMPTY_OUTPUT
    /\ ~USE_FIXED
    /\ state' = "submitted"
    /\ resourceRegistered' = FALSE
    /\ returnedJobId' = "none"

SubmitEmptyFixed ==
    /\ state = "ready"
    /\ EMPTY_OUTPUT
    /\ USE_FIXED
    /\ state' = "rejected"
    /\ resourceRegistered' = FALSE
    /\ returnedJobId' = "none"

Next ==
    \/ SubmitSuccess
    \/ SubmitEmptyCurrent
    \/ SubmitEmptyFixed
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in States
    /\ resourceRegistered \in BOOLEAN
    /\ returnedJobId \in {"none", "job-1"}

SubmitContract ==
    state = "submitted" =>
        /\ resourceRegistered
        /\ returnedJobId # "none"

RejectedHasNoResource ==
    state = "rejected" =>
        /\ ~resourceRegistered
        /\ returnedJobId = "none"

=============================================================================
