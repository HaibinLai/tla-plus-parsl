--------------------------- MODULE ParslTasksOutgoing ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Bounded model of high_throughput.zmq_pipes.TasksOutgoing.put/close.
 *
 * The DEALER sender publishes a Python object without a reply handshake.
 * A put is valid only while the socket is open; close terminates the sender
 * and no later task message may be accepted by the wrapper.
 ***************************************************************************)

CONSTANT MAX_MESSAGES

States == {"open", "closed"}

VARIABLES state, sentCount
vars == <<state, sentCount>>

Init ==
    /\ MAX_MESSAGES \in Nat
    /\ state = "open"
    /\ sentCount = 0

Put ==
    /\ state = "open"
    /\ sentCount < MAX_MESSAGES
    /\ sentCount' = sentCount + 1
    /\ UNCHANGED state

Close ==
    /\ state = "open"
    /\ state' = "closed"
    /\ UNCHANGED sentCount

Next ==
    \/ Put
    \/ Close
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in States
    /\ sentCount \in 0..MAX_MESSAGES

ClosedSendSafety ==
    state = "closed" => sentCount <= MAX_MESSAGES

=============================================================================
