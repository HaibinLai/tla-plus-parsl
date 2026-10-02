--------------------------- MODULE ParslRadicalMasterSubmitShape ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Radical-Pilot master admission.
 *
 * RadicalPilotExecutor.start() indexes submit_raptors(md)[0] without first
 * validating the returned collection.  An empty successful-looking response
 * therefore leaks IndexError.  The fixed branch converts it into an explicit
 * startup failure and leaves no master published.
 ***************************************************************************)

CONSTANTS USE_FIXED, RESPONSE_COUNT

VARIABLES response, outcome, masterPublished
vars == <<response, outcome, masterPublished>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ RESPONSE_COUNT \in 0..1
    /\ response = RESPONSE_COUNT
    /\ outcome = "starting"
    /\ masterPublished = FALSE

SubmitMaster ==
    /\ outcome = "starting"
    /\ IF response = 0
          THEN IF USE_FIXED
               THEN /\ outcome' = "startup-failed"
                    /\ UNCHANGED masterPublished
               ELSE /\ outcome' = "raw-index-error"
                    /\ UNCHANGED masterPublished
          ELSE /\ outcome' = "started"
               /\ masterPublished' = TRUE
    /\ UNCHANGED response

Next == SubmitMaster \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ response \in 0..1
    /\ outcome \in {"starting", "started", "startup-failed", "raw-index-error"}
    /\ masterPublished \in BOOLEAN

StartupOutcomeSafety == outcome # "raw-index-error"
MasterPublicationSafety == outcome = "started" => masterPublished

=============================================================================
