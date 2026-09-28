--------------------------- MODULE ParslTorqueSubmit ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Bounded model of TorqueProvider.submit.
 *
 * A successful qsub output is parsed line by line; each non-empty line is
 * registered and the last non-empty line becomes the returned job id.  Empty
 * successful output and non-zero qsub output return None without a resource.
 ***************************************************************************)

CONSTANTS API_SUCCESS, OUTPUT_HAS_ID

States == {"new", "script_written", "submitted", "registered", "rejected"}

VARIABLES state, resource, returnedId
vars == <<state, resource, returnedId>>

Init ==
    /\ API_SUCCESS \in BOOLEAN
    /\ OUTPUT_HAS_ID \in BOOLEAN
    /\ state = "new"
    /\ resource = "none"
    /\ returnedId = "none"

WriteScript ==
    /\ state = "new"
    /\ state' = "script_written"
    /\ UNCHANGED <<resource, returnedId>>

ExecuteQsub ==
    /\ state = "script_written"
    /\ state' = "submitted"
    /\ UNCHANGED <<resource, returnedId>>

ParseQsub ==
    /\ state = "submitted"
    /\ IF API_SUCCESS /\ OUTPUT_HAS_ID THEN
           /\ state' = "registered"
           /\ resource' = "job-1"
           /\ returnedId' = "job-1"
       ELSE
           /\ state' = "rejected"
           /\ resource' = "none"
           /\ returnedId' = "none"

Next ==
    \/ WriteScript
    \/ ExecuteQsub
    \/ ParseQsub
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in States
    /\ resource \in {"none", "job-1"}
    /\ returnedId \in {"none", "job-1"}

RegistrationSafety ==
    /\ state = "registered" => resource = returnedId
    /\ state = "rejected" => resource = "none" /\ returnedId = "none"

=============================================================================
