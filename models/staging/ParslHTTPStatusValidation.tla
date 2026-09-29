--------------------------- MODULE ParslHTTPStatusValidation ---------------------------
EXTENDS Naturals

(***************************************************************************
 * HTTP staging response validation.
 *
 * HTTPInTaskStaging writes any response body returned by requests.get and then
 * invokes the user task; it does not check the HTTP status code.  USE_FIXED
 * represents rejecting non-2xx responses before publishing the body or
 * starting the task.
 ***************************************************************************)

CONSTANTS STATUS_CODE, USE_FIXED
VARIABLES state, bodyPublished, taskStarted
vars == <<state, bodyPublished, taskStarted>>

Init ==
    /\ STATUS_CODE \in 100..599
    /\ USE_FIXED \in BOOLEAN
    /\ state = "requested"
    /\ bodyPublished = FALSE
    /\ taskStarted = FALSE

Receive ==
    /\ state = "requested"
    /\ state' = "received"
    /\ UNCHANGED <<bodyPublished, taskStarted>>

AcceptResponse ==
    /\ state = "received"
    /\ IF USE_FIXED THEN STATUS_CODE \in 200..299 ELSE TRUE
    /\ state' = "accepted"
    /\ UNCHANGED <<bodyPublished, taskStarted>>

RejectResponse ==
    /\ state = "received"
    /\ USE_FIXED
    /\ STATUS_CODE \notin 200..299
    /\ state' = "rejected"
    /\ UNCHANGED <<bodyPublished, taskStarted>>

WriteBody ==
    /\ state = "accepted"
    /\ state' = "written"
    /\ bodyPublished' = TRUE
    /\ UNCHANGED taskStarted

StartTask ==
    /\ state = "written"
    /\ state' = "completed"
    /\ taskStarted' = TRUE
    /\ UNCHANGED bodyPublished

Next ==
    \/ Receive
    \/ AcceptResponse
    \/ RejectResponse
    \/ WriteBody
    \/ StartTask
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in {"requested", "received", "accepted", "rejected", "written", "completed"}
    /\ bodyPublished \in BOOLEAN
    /\ taskStarted \in BOOLEAN

StatusSafety == taskStarted => STATUS_CODE \in 200..299
PublicationSafety == taskStarted => bodyPublished
=============================================================================
