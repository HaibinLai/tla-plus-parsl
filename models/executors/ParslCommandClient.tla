--------------------------- MODULE ParslCommandClient ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Focused REQ/REP command-client lifecycle from high_throughput.zmq_pipes.
 * A response timeout marks the client permanently bad; a later call is
 * rejected instead of reusing a request socket with an unknown state.
 *************************************************************************** *)

CONSTANT MODE

Modes == {"reply", "timeout"}
States == {"ready", "sent", "replied", "bad"}
VARIABLES state, runCount
vars == <<state, runCount>>

Init ==
    /\ MODE \in Modes
    /\ state = "ready"
    /\ runCount = 0

SendCommand ==
    /\ state = "ready"
    /\ runCount = 0
    /\ state' = "sent"
    /\ runCount' = 1

ReceiveReply ==
    /\ state = "sent"
    /\ MODE = "reply"
    /\ state' = "replied"
    /\ UNCHANGED runCount

ResponseTimeout ==
    /\ state = "sent"
    /\ MODE = "timeout"
    /\ state' = "bad"
    /\ UNCHANGED runCount

Next ==
    \/ SendCommand
    \/ ReceiveReply
    \/ ResponseTimeout
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in States
    /\ runCount \in 0..1

TimeoutPoisonSafety ==
    state = "bad" => MODE = "timeout"

NoReuseAfterTimeout ==
    state = "bad" => runCount = 1

=============================================================================
