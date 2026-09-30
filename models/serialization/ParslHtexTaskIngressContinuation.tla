--------------------------- MODULE ParslHtexTaskIngressContinuation ---------------------------
EXTENDS Naturals, Sequences

(***************************************************************************
 * Continuation after malformed HTEX task ingress.
 *
 * A malformed decoded task can arrive immediately before a valid task on the
 * same ZMQ channel.  The current process_task_incoming path lets the first
 * exception escape, so the loop never reaches the valid message.  The fixed
 * branch discards the malformed envelope and continues with the next frame.
 * This is a sequence refinement of the single-message BUG-098 boundary.
 ***************************************************************************)

CONSTANT USE_FIXED

Messages == <<"malformed", "valid">>

VARIABLES cursor, ingressAlive, queued
vars == <<cursor, ingressAlive, queued>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ cursor = 1
    /\ ingressAlive = TRUE
    /\ queued = 0

ReceiveMalformed ==
    /\ cursor = 1
    /\ IF USE_FIXED
          THEN /\ cursor' = 2
               /\ ingressAlive' = TRUE
               /\ queued' = 0
          ELSE /\ UNCHANGED cursor
               /\ ingressAlive' = FALSE
               /\ queued' = 0

ReceiveValid ==
    /\ cursor = 2
    /\ ingressAlive
    /\ cursor' = 3
    /\ ingressAlive' = TRUE
    /\ queued' = queued + 1

Next ==
    \/ ReceiveMalformed
    \/ ReceiveValid
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ cursor \in 1..3
    /\ ingressAlive \in BOOLEAN
    /\ queued \in 0..1

IngressSurvival == ingressAlive
ValidMessageProgress == cursor = 3 => queued = 1

=============================================================================
