--------------------------- MODULE ParslGridEngineSubmitShape ---------------------------
EXTENDS Naturals

(***************************************************************************
 * GridEngineProvider.submit accepts the first non-empty qsub stdout line as
 * a resource ID.  USE_FIXED models validating the scheduler identifier
 * before publishing provider bookkeeping.
 ***************************************************************************)

CONSTANTS RESPONSE_KIND, USE_FIXED
VARIABLES state, resourcePublished
vars == <<state, resourcePublished>>

Init ==
    /\ RESPONSE_KIND \in {"valid-id", "malformed"}
    /\ USE_FIXED \in BOOLEAN
    /\ state = "waiting"
    /\ resourcePublished = FALSE

ProcessResponse ==
    /\ state = "waiting"
    /\ IF USE_FIXED /\ RESPONSE_KIND = "malformed"
          THEN state' = "rejected" ELSE state' = "submitted"
    /\ resourcePublished' = IF USE_FIXED /\ RESPONSE_KIND = "malformed"
                                  THEN FALSE ELSE TRUE

Next == ProcessResponse \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ RESPONSE_KIND \in {"valid-id", "malformed"}
    /\ state \in {"waiting", "submitted", "rejected"}
    /\ resourcePublished \in BOOLEAN

SubmitShapeSafety == state = "submitted" => RESPONSE_KIND = "valid-id"
PublicationSafety == state = "rejected" => ~resourcePublished
=============================================================================
