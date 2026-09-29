--------------------------- MODULE ParslHtexTaskMessageMalformed ---------------------------
EXTENDS Naturals

(***************************************************************************
 * HTEX interchange task-incoming decoding.
 *
 * process_task_socket_message indexes task_id and context before placing a
 * task into the pending queue.  A malformed Python object can therefore
 * escape the polling loop.  USE_FIXED models discarding the object and
 * keeping the interchange alive.
 ***************************************************************************)

CONSTANT USE_FIXED
VARIABLES message, state, queued
vars == <<message, state, queued>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ message = "missing-context"
    /\ state = "ready"
    /\ queued = 0

Receive ==
    /\ state = "ready"
    /\ state' = IF USE_FIXED THEN "ignored" ELSE "crashed"
    /\ queued' = IF USE_FIXED THEN queued ELSE queued
    /\ UNCHANGED message

Next == Receive \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ message = "missing-context"
    /\ state \in {"ready", "ignored", "crashed"}
    /\ queued = 0

MalformedTaskSafety == state # "crashed"
=============================================================================
