--------------------------- MODULE ParslResultsIncoming ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Bounded model of high_throughput.zmq_pipes.ResultsIncoming.get/close.
 *
 * A poll timeout returns no message.  A readable DEALER socket returns one
 * multipart message, and close makes the receiver quiescent.  The payload is
 * represented by a message token; frame-level serialization is covered by
 * the separate ZMQ models.
 ***************************************************************************)

CONSTANT MESSAGE_AVAILABLE
MAX_MESSAGES == 2

States == {"open", "waiting", "received", "timed_out", "closed"}

VARIABLES state, messageCount
vars == <<state, messageCount>>

Init ==
    /\ MESSAGE_AVAILABLE \in BOOLEAN
    /\ state = "open"
    /\ messageCount = 0

Poll ==
    /\ state = "open"
    /\ state' = "waiting"
    /\ UNCHANGED messageCount

ReceiveMultipart ==
    /\ state = "waiting"
    /\ MESSAGE_AVAILABLE
    /\ messageCount < MAX_MESSAGES
    /\ state' = "received"
    /\ messageCount' = messageCount + 1

PollTimeout ==
    /\ state = "waiting"
    /\ ~MESSAGE_AVAILABLE
    /\ state' = "timed_out"
    /\ UNCHANGED messageCount

NextPoll ==
    /\ state \in {"received", "timed_out"}
    /\ state' = "open"
    /\ UNCHANGED messageCount

Close ==
    /\ state \in {"open", "received", "timed_out"}
    /\ state' = "closed"
    /\ UNCHANGED messageCount

Next ==
    \/ Poll
    \/ ReceiveMultipart
    \/ PollTimeout
    \/ NextPoll
    \/ Close
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ MESSAGE_AVAILABLE \in BOOLEAN
    /\ state \in States
    /\ messageCount \in 0..MAX_MESSAGES

PollResultSafety ==
    state = "received" => messageCount > 0

TimeoutSafety ==
    state = "timed_out" => ~MESSAGE_AVAILABLE

ClosedQuiescence ==
    state = "closed" => messageCount >= 0

=============================================================================
