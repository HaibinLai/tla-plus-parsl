--------------------------- MODULE ParslCommandClientSendTimeout ---------------------------
EXTENDS Naturals

(***************************************************************************
 * CommandClient.run distinguishes a timeout before send (POLLOUT not ready)
 * from one after send (reply timeout).  The former has not changed the REQ
 * socket state and leaves client.ok true, so a later command may succeed.
 *************************************************************************** *)

VARIABLES state, sent, clientOK, result
vars == <<state, sent, clientOK, result>>

Init ==
    /\ state = "ready"
    /\ sent = 0
    /\ clientOK = TRUE
    /\ result = "none"

PreSendTimeout ==
    /\ state = "ready" /\ clientOK /\ sent = 0
    /\ state' = "ready"
    /\ sent' = 0
    /\ clientOK' = TRUE
    /\ result' = "send-timeout"

Send ==
    /\ state = "ready" /\ clientOK
    /\ state' = "sent"
    /\ sent' = sent + 1
    /\ UNCHANGED <<clientOK, result>>

Reply ==
    /\ state = "sent"
    /\ state' = "done"
    /\ result' = "reply"
    /\ UNCHANGED <<sent, clientOK>>

Done ==
    /\ state = "done"
    /\ UNCHANGED vars

Next == PreSendTimeout \/ Send \/ Reply \/ Done
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in {"ready", "sent", "done"}
    /\ sent \in Nat
    /\ clientOK \in BOOLEAN
    /\ result \in {"none", "send-timeout", "reply"}

PreSendTimeoutReusable ==
    result = "send-timeout" => clientOK

ReplyRequiresSend ==
    result = "reply" => sent = 1

=============================================================================
