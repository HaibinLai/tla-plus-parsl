--------------------------- MODULE ParslGridEngineEmptySubmit ---------------------------
EXTENDS Naturals

(***************************************************************************
 * A successful Grid Engine qsub command with empty stdout yields no job ID.
 * The current provider returns None and leaves the caller to publish an
 * unusable block mapping.  USE_FIXED models an explicit failed submission.
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
    /\ state' = IF USE_FIXED THEN "rejected" ELSE "returned-none"
    /\ UNCHANGED jobIdPresent

Next == ProcessEmptyResponse \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in {"waiting", "returned-none", "rejected"}
    /\ jobIdPresent \in BOOLEAN

SubmitOutcomeSafety == state = "returned-none" => jobIdPresent
=============================================================================
