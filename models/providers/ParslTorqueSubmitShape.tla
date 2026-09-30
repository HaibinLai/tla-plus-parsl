--------------------------- MODULE ParslTorqueSubmitShape ---------------------------
EXTENDS Naturals

(***************************************************************************
 * TorqueProvider.submit registers every non-empty qsub stdout line and
 * returns the last one.  USE_FIXED models accepting exactly one validated
 * scheduler identifier before publishing provider state.
 ***************************************************************************)

CONSTANT USE_FIXED
VARIABLES state, publishedCount, returnedId
vars == <<state, publishedCount, returnedId>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ state = "waiting"
    /\ publishedCount = 0
    /\ returnedId = "none"

ProcessTwoLineResponse ==
    /\ state = "waiting"
    /\ state' = IF USE_FIXED THEN "rejected" ELSE "submitted"
    /\ publishedCount' = IF USE_FIXED THEN 0 ELSE 2
    /\ returnedId' = IF USE_FIXED THEN "none" ELSE "second"

Next == ProcessTwoLineResponse \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in {"waiting", "submitted", "rejected"}
    /\ publishedCount \in 0..2
    /\ returnedId \in {"none", "second"}

SubmitShapeSafety == state = "submitted" => publishedCount = 1
RegistrationSafety == state = "submitted" => returnedId # "none"
=============================================================================
