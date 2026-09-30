--------------------------- MODULE ParslHTTPSeparateStatus ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Separate-task HTTP stage-in response validation.
 *
 * The current _http_stage_in helper streams the body and completes the
 * staging task without checking the response status code.  USE_FIXED models
 * rejecting non-success responses before publishing bytes to the destination.
 ***************************************************************************)

CONSTANTS STATUS_CODE, USE_FIXED
VARIABLES state, bodyPublished, stagingSucceeded
vars == <<state, bodyPublished, stagingSucceeded>>

Init ==
    /\ STATUS_CODE \in 100..599
    /\ USE_FIXED \in BOOLEAN
    /\ state = "requested"
    /\ bodyPublished = FALSE
    /\ stagingSucceeded = FALSE

Receive ==
    /\ state = "requested"
    /\ state' = "received"
    /\ UNCHANGED <<bodyPublished, stagingSucceeded>>

AcceptResponse ==
    /\ state = "received"
    /\ IF USE_FIXED THEN STATUS_CODE \in 200..299 ELSE TRUE
    /\ state' = "accepted"
    /\ UNCHANGED <<bodyPublished, stagingSucceeded>>

RejectResponse ==
    /\ state = "received"
    /\ USE_FIXED
    /\ STATUS_CODE \notin 200..299
    /\ state' = "rejected"
    /\ UNCHANGED <<bodyPublished, stagingSucceeded>>

WriteBody ==
    /\ state = "accepted"
    /\ state' = "written"
    /\ bodyPublished' = TRUE
    /\ UNCHANGED stagingSucceeded

Complete ==
    /\ state = "written"
    /\ state' = "completed"
    /\ stagingSucceeded' = TRUE
    /\ UNCHANGED bodyPublished

Next ==
    \/ Receive
    \/ AcceptResponse
    \/ RejectResponse
    \/ WriteBody
    \/ Complete
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in {"requested", "received", "accepted", "rejected", "written", "completed"}
    /\ bodyPublished \in BOOLEAN
    /\ stagingSucceeded \in BOOLEAN

StatusSafety == stagingSucceeded => STATUS_CODE \in 200..299
PublicationSafety == stagingSucceeded => bodyPublished
=============================================================================
