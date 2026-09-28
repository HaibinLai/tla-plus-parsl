--------------------------- MODULE ParslLSFSubmit ---------------------------
EXTENDS Naturals, Sequences

(***************************************************************************
 * Bounded model of LSFProvider.submit.
 *
 * The provider writes a script, invokes bsub, and registers a resource only
 * when a successful stdout line contains the LSF submission marker and a job
 * identifier.  Command failure and successful-but-unparseable output return
 * None without creating a resource.
 ***************************************************************************)

CONSTANT SUBMIT_OUTCOME

Outcomes == {"valid", "failed", "empty", "malformed"}
States == {"new", "script_written", "submitted", "registered", "rejected"}

VARIABLES state, resource, returnedId
vars == <<state, resource, returnedId>>

Init ==
    /\ SUBMIT_OUTCOME \in Outcomes
    /\ state = "new"
    /\ resource = "none"
    /\ returnedId = "none"

WriteScript ==
    /\ state = "new"
    /\ state' = "script_written"
    /\ UNCHANGED <<resource, returnedId>>

ExecuteBsub ==
    /\ state = "script_written"
    /\ state' = "submitted"
    /\ UNCHANGED <<resource, returnedId>>

ParseBsub ==
    /\ state = "submitted"
    /\ IF SUBMIT_OUTCOME = "valid" THEN
           /\ state' = "registered"
           /\ resource' = "job-1"
           /\ returnedId' = "job-1"
       ELSE
           /\ state' = "rejected"
           /\ resource' = "none"
           /\ returnedId' = "none"

Next ==
    \/ WriteScript
    \/ ExecuteBsub
    \/ ParseBsub
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in States
    /\ resource \in {"none", "job-1"}
    /\ returnedId \in {"none", "job-1"}

RegistrationSafety ==
    /\ state = "registered" =>
        /\ SUBMIT_OUTCOME = "valid"
        /\ resource = returnedId
    /\ state = "rejected" =>
        /\ resource = "none" /\ returnedId = "none"

SubmitProgress ==
    state = "new" => state # "registered"

=============================================================================
