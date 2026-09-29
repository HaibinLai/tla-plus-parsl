--------------------------- MODULE ParslHtexTaskPriorityType ---------------------------
EXTENDS Naturals

(***************************************************************************
 * HTEX task priority object typing.
 *
 * process_task_incoming computes (-priority, -task_id, msg).  A serialized
 * task carrying a non-numeric priority reaches unary negation and escapes the
 * interchange loop.  USE_FIXED models rejecting that object before queueing.
 ***************************************************************************)

CONSTANT USE_FIXED
VARIABLES priority, state, queued
vars == <<priority, state, queued>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ priority = "string"
    /\ state = "ready"
    /\ queued = 0

Receive ==
    /\ state = "ready"
    /\ state' = IF USE_FIXED THEN "ignored" ELSE "crashed"
    /\ queued' = 0
    /\ UNCHANGED priority

Next == Receive \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ priority = "string"
    /\ state \in {"ready", "ignored", "crashed"}
    /\ queued = 0

PriorityTypingSafety == state # "crashed"
=============================================================================
