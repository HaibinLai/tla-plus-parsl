--------------------------- MODULE ParslHtexTaskIdType ---------------------------
EXTENDS Naturals

(***************************************************************************
 * HTEX task-ingress typing.  process_task_incoming uses unary minus on the
 * decoded task_id while building the priority queue entry.  A pickleable
 * non-numeric ID therefore escapes the ingress loop unless the envelope is
 * validated first.
 ***************************************************************************)

CONSTANT USE_FIXED
VARIABLES state, queued
vars == <<state, queued>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ state = "received"
    /\ queued = FALSE

ProcessMessage ==
    /\ state = "received"
    /\ state' = IF USE_FIXED THEN "ignored" ELSE "crashed"
    /\ queued' = FALSE

Next == ProcessMessage \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in {"received", "ignored", "crashed"}
    /\ queued \in BOOLEAN

NoIngressCrash == state # "crashed"

=============================================================================
