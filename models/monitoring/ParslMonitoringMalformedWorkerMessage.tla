--------------------------- MODULE ParslMonitoringMalformedWorkerMessage ---------------------------
EXTENDS Naturals

(***************************************************************************
 * DatabaseManager worker-task message validation.
 *
 * A worker message must be either first_msg or last_msg.  The current
 * processing loop raises for an object with both flags false, terminating the
 * monitoring thread.  USE_FIXED models logging and discarding the malformed
 * message while preserving the database worker.
 ***************************************************************************)

CONSTANT USE_FIXED
VARIABLES message, workerState
vars == <<message, workerState>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ message = "neither-first-nor-last"
    /\ workerState = "alive"

Process ==
    /\ workerState = "alive"
    /\ workerState' = IF USE_FIXED THEN "alive" ELSE "crashed"
    /\ UNCHANGED message

Next == Process \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ message = "neither-first-nor-last"
    /\ workerState \in {"alive", "crashed"}

MalformedIsolation == workerState = "alive"
=============================================================================
