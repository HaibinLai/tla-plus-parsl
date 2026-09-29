--------------------------- MODULE ParslCommandClientCloseRace ---------------------------
EXTENDS Naturals

(***************************************************************************
 * CommandClient.close terminates the socket but the current implementation
 * leaves ok=TRUE. A later run therefore passes the health check and reaches
 * a terminated socket. The fixed branch marks the client unusable at close.
 ***************************************************************************)

CONSTANT USE_FIXED
States == {"open", "closed", "sending", "rejected", "socket-error"}

VARIABLES state, ok
vars == <<state, ok>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ state = "open"
    /\ ok = TRUE

Close ==
    /\ state = "open"
    /\ state' = "closed"
    /\ ok' = IF USE_FIXED THEN FALSE ELSE TRUE

RunHealthCheck ==
    /\ state = "closed"
    /\ ok
    /\ state' = "sending"
    /\ UNCHANGED ok

SendOnClosedSocket ==
    /\ state = "sending"
    /\ state' = "socket-error"
    /\ UNCHANGED ok

RunRejected ==
    /\ state = "closed"
    /\ ~ok
    /\ state' = "rejected"
    /\ UNCHANGED ok

Next ==
    \/ Close
    \/ RunHealthCheck
    \/ SendOnClosedSocket
    \/ RunRejected
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in States
    /\ ok \in BOOLEAN

NoClosedSocketUse == state = "sending" => FALSE

=============================================================================
