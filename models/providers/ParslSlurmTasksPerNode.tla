------------------------- MODULE ParslSlurmTasksPerNode -------------------------
EXTENDS Naturals

(***************************************************************************
 * SlurmProvider.submit tasks_per_node admission.
 *
 * When cores_per_node is configured, submit computes cpus-per-task by dividing
 * by tasks_per_node. The current path lets zero reach that division and
 * exposes ZeroDivisionError; the fixed branch rejects the invalid request
 * before constructing a submit script.
 ***************************************************************************)

CONSTANTS TASKS_PER_NODE, USE_FIXED
VARIABLE state
vars == <<state>>

Init ==
    /\ TASKS_PER_NODE \in 0..2
    /\ USE_FIXED \in BOOLEAN
    /\ state = "requested"

Submit ==
    /\ state = "requested"
    /\ IF USE_FIXED THEN TASKS_PER_NODE > 0 ELSE TRUE
    /\ state' = IF TASKS_PER_NODE = 0 THEN "division-error" ELSE "submitted"

Reject ==
    /\ state = "requested"
    /\ USE_FIXED
    /\ TASKS_PER_NODE = 0
    /\ state' = "rejected"

Next == Submit \/ Reject \/ UNCHANGED state
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in {"requested", "division-error", "submitted", "rejected"}

NoDivisionError == state # "division-error"
ValidSubmit == state = "submitted" => TASKS_PER_NODE > 0

=============================================================================
