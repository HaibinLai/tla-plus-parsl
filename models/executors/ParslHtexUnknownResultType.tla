--------------------------- MODULE ParslHtexUnknownResultType ---------------------------
EXTENDS Naturals

(***************************************************************************
 * HighThroughputExecutor._result_queue_worker raises BadMessage for an
 * unknown result type.  That terminates the result worker and strands later
 * valid frames.  USE_FIXED discards the malformed frame and continues.
 ***************************************************************************)

CONSTANT USE_FIXED
VARIABLES phase, valid_future, outcome
vars == <<phase, valid_future, outcome>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ phase = "unknown_frame"
    /\ valid_future = "pending"
    /\ outcome = "waiting"

HandleUnknown ==
    /\ phase = "unknown_frame"
    /\ phase' = IF USE_FIXED THEN "valid_frame" ELSE "stopped"
    /\ valid_future' = "pending"
    /\ outcome' = IF USE_FIXED THEN "continue" ELSE "worker_crash"

HandleValid ==
    /\ phase = "valid_frame"
    /\ phase' = "complete"
    /\ valid_future' = "resolved"
    /\ outcome' = "complete"

Next == HandleUnknown \/ HandleValid \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ phase \in {"unknown_frame", "valid_frame", "stopped", "complete"}
    /\ valid_future \in {"pending", "resolved"}
    /\ outcome \in {"waiting", "continue", "worker_crash", "complete"}

UnknownTypeSafety == phase = "stopped" => valid_future # "pending"
=============================================================================
