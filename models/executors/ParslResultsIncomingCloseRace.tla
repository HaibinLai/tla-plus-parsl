--------------------------- MODULE ParslResultsIncomingCloseRace ---------------------------
EXTENDS Naturals

(***************************************************************************
 * ResultsIncoming.get racing with ResultsIncoming.close.
 *
 * The current wrapper closes the ZeroMQ socket but has no closed guard in
 * get(), so a collector call after close reaches a terminated socket.  The
 * fixed branch treats that call as a quiescent no-message result.
 ***************************************************************************)

CONSTANT USE_FIXED
States == {"open", "closed", "received", "error"}

VARIABLES state, getResult
vars == <<state, getResult>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ state = "open"
    /\ getResult = "none"

Close ==
    /\ state \in {"open", "received"}
    /\ state' = "closed"
    /\ UNCHANGED getResult

GetAfterClose ==
    /\ state = "closed"
    /\ IF USE_FIXED
          THEN /\ state' = "closed"
               /\ getResult' = "none"
          ELSE /\ state' = "error"
               /\ getResult' = "socket-error"

Receive ==
    /\ state = "open"
    /\ state' = "received"
    /\ getResult' = "message"

Next ==
    \/ Close
    \/ GetAfterClose
    \/ Receive
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ state \in States
    /\ getResult \in {"none", "message", "socket-error"}

CloseSafety == state = "error" => USE_FIXED
=============================================================================
