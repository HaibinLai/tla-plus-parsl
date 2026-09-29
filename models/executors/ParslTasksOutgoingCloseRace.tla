--------------------------- MODULE ParslTasksOutgoingCloseRace ---------------------------
EXTENDS Naturals

(***************************************************************************
 * TasksOutgoing close/put lifecycle.
 *
 * TasksOutgoing.close terminates the DEALER socket, but the current put path
 * has no closed-state guard.  A post-close put therefore reaches the dead
 * socket and exposes a transport exception.  The fixed branch rejects the
 * message before touching the socket.
 ***************************************************************************)

CONSTANT USE_FIXED

States == {"open", "closed", "rejected", "crashed"}

VARIABLES state, sent
vars == <<state, sent>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ state = "open"
    /\ sent = 0

Close ==
    /\ state = "open"
    /\ state' = "closed"
    /\ UNCHANGED sent

PutAfterClose ==
    /\ state = "closed"
    /\ IF USE_FIXED
          THEN state' = "rejected"
          ELSE state' = "crashed"
    /\ UNCHANGED sent

Next ==
    \/ Close
    \/ PutAfterClose
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in States
    /\ sent \in Nat

NoClosedSendCrash == state # "crashed"

=============================================================================
