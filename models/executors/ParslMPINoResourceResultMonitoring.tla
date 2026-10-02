--------------------------- MODULE ParslMPINoResourceResultMonitoring ---------------------------
EXTENDS Naturals

(***************************************************************************
 * MPI result delivery, logical Future completion, and monitoring terminality.
 *
 * A successful MPI result for a task that requested no nodes has no entry in
 * _map_tasks_to_nodes.  The current scheduler asserts before returning the
 * result, so the executor cannot resolve its Future or publish a terminal
 * monitoring event.  USE_FIXED models conditional node release while always
 * returning the decoded result.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES mapped, phase, future, monitor
vars == <<mapped, phase, future, monitor>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ mapped = FALSE
    /\ phase = "queued"
    /\ future = "pending"
    /\ monitor = "none"

ConsumeResult ==
    /\ phase = "queued"
    /\ phase' = IF mapped \/ USE_FIXED THEN "returned" ELSE "assertion"
    /\ future' = IF mapped \/ USE_FIXED THEN "ready" ELSE future
    /\ monitor' = IF mapped \/ USE_FIXED THEN "ready" ELSE monitor
    /\ UNCHANGED mapped

Done ==
    /\ phase \in {"returned", "assertion"}
    /\ UNCHANGED vars

Next == ConsumeResult \/ Done
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ mapped \in BOOLEAN
    /\ phase \in {"queued", "returned", "assertion"}
    /\ future \in {"pending", "ready"}
    /\ monitor \in {"none", "ready"}

NoRawAssertion == phase # "assertion"
FutureTerminality == phase = "returned" => future = "ready"
MonitoringTerminality == phase = "returned" => monitor = "ready"

================================================================================
