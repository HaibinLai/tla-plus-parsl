--------------------------- MODULE ParslCommandSendFailure ---------------------------
EXTENDS Naturals

(***************************************************************************
 * CommandClient.run marks the client bad when a response timeout occurs, but
 * a send_pyobj exception currently escapes without changing ``ok``.  A later
 * command can therefore reuse a failed REQ socket.  USE_FIXED marks the
 * client unusable on send failure as well.
 ***************************************************************************)

CONSTANT SEND_RESULT, USE_FIXED
VARIABLES client, phase, outcome
vars == <<client, phase, outcome>>

Init ==
    /\ SEND_RESULT \in {"success", "failure"}
    /\ USE_FIXED \in BOOLEAN
    /\ client = "healthy"
    /\ phase = "first-send"
    /\ outcome = "waiting"

Send ==
    /\ phase = "first-send"
    /\ SEND_RESULT = "success"
    /\ phase' = "complete"
    /\ client' = client
    /\ outcome' = "sent"

SendFailure ==
    /\ phase = "first-send"
    /\ SEND_RESULT = "failure"
    /\ phase' = "failed-send"
    /\ client' = IF USE_FIXED THEN "bad" ELSE "healthy"
    /\ outcome' = "send-error"

RetryAfterFailure ==
    /\ phase = "failed-send"
    /\ phase' = "complete"
    /\ client = "healthy"
    /\ client' = client
    /\ outcome' = "reused"

Next == Send \/ SendFailure \/ RetryAfterFailure \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ client \in {"healthy", "bad"}
    /\ phase \in {"first-send", "failed-send", "complete"}
    /\ outcome \in {"waiting", "sent", "send-error", "reused"}

SendFailureSafety == phase = "failed-send" => client = "bad"
=============================================================================
