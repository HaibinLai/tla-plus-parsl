--------------------------- MODULE ParslLocalTasksPerNode ---------------------------
EXTENDS Naturals

(***************************************************************************
 * LocalProvider tasks_per_node validation.
 *
 * A zero tasks_per_node value currently reaches the generated launcher script
 * and produces a failed local job.  USE_FIXED represents rejecting the invalid
 * resource request before creating a process.
 *************************************************************************** *)

CONSTANTS TASKS_PER_NODE, USE_FIXED
VARIABLE state
vars == <<state>>

Init ==
    /\ TASKS_PER_NODE \in 0..1
    /\ USE_FIXED \in BOOLEAN
    /\ state = "requested"

Submit ==
    /\ state = "requested"
    /\ IF USE_FIXED THEN TASKS_PER_NODE > 0 ELSE TRUE
    /\ state' = IF TASKS_PER_NODE > 0 THEN "running" ELSE "failed"

Reject ==
    /\ state = "requested"
    /\ USE_FIXED
    /\ TASKS_PER_NODE = 0
    /\ state' = "rejected"

Next == Submit \/ Reject \/ UNCHANGED state
Spec == Init /\ [][Next]_vars

TypeOK == state \in {"requested", "running", "failed", "rejected"}
ValidLaunchSafety == state = "running" => TASKS_PER_NODE > 0
NoInvalidProcess == state # "failed"
=============================================================================
