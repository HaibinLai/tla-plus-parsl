--------------------------- MODULE ParslCommandReceiveFailure ---------------------------
EXTENDS Naturals

(***************************************************************************
 * CommandClient response-deserialization failure.
 *
 * A recv_pyobj() exception escapes the current CommandClient.run path without
 * poisoning the REQ socket.  The fixed branch marks the client bad before
 * propagating the transport/decode error, so a later command cannot reuse an
 * unknown request state.
 ***************************************************************************)

CONSTANT USE_FIXED

States == {"ready", "sent", "replied", "receive_failed", "bad"}
VARIABLES state, healthy, runCount
vars == <<state, healthy, runCount>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ state = "ready"
    /\ healthy = TRUE
    /\ runCount = 0

SendCommand ==
    /\ state = "ready"
    /\ runCount = 0
    /\ state' = "sent"
    /\ runCount' = 1
    /\ UNCHANGED healthy

ReceiveReply ==
    /\ state = "sent"
    /\ state' = "replied"
    /\ UNCHANGED <<healthy, runCount>>

ReceiveFailure ==
    /\ state = "sent"
    /\ state' = IF USE_FIXED THEN "bad" ELSE "receive_failed"
    /\ healthy' = IF USE_FIXED THEN FALSE ELSE TRUE
    /\ UNCHANGED runCount

Next ==
    \/ SendCommand
    \/ ReceiveReply
    \/ ReceiveFailure
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ state \in States
    /\ healthy \in BOOLEAN
    /\ runCount \in 0..1

ReceiveFailureSafety ==
    state = "receive_failed" => ~healthy

NoReuseAfterReceiveFailure ==
    state = "receive_failed" => ~healthy

=============================================================================
