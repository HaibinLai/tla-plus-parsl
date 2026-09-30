--------------------------- MODULE ParslMonitoringZMQTupleShape ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Monitoring ZMQ router message-shape boundary.
 *
 * MonitoringRouter accepts exactly two-element tuples.  A malformed tuple is
 * discarded by the receiver loop; a valid tuple is forwarded to the internal
 * monitoring queue.  The model keeps the payload opaque and focuses on this
 * admission boundary.
 ***************************************************************************)

CONSTANT TUPLE_ARITY

States == {"received", "forwarded", "discarded"}

VARIABLES state, forwarded
vars == <<state, forwarded>>

Init ==
    /\ TUPLE_ARITY \in 0..3
    /\ state = "received"
    /\ forwarded = FALSE

Handle ==
    /\ state = "received"
    /\ state' = IF TUPLE_ARITY = 2 THEN "forwarded" ELSE "discarded"
    /\ forwarded' = (TUPLE_ARITY = 2)

Next ==
    \/ Handle
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ TUPLE_ARITY \in 0..3
    /\ state \in States
    /\ forwarded \in BOOLEAN

ShapeSafety ==
    state = "forwarded" => TUPLE_ARITY = 2

ForwardingSafety ==
    forwarded => state = "forwarded"

=============================================================================
