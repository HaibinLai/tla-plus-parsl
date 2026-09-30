--------------------------- MODULE ParslMPINoResourceResult ---------------------------
EXTENDS Naturals

(***************************************************************************
 * MPITaskScheduler.get_result currently assumes every successful task has an
 * entry in _map_tasks_to_nodes. Tasks without a num_nodes resource request
 * have no such entry, so the assertion is reached before the result returns.
 * USE_FIXED models conditional node release with normal result delivery.
 *************************************************************************** *)

CONSTANT USE_FIXED

VARIABLES mapped, result, phase
vars == <<mapped, result, phase>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ mapped = FALSE
    /\ result = "ready"
    /\ phase = "queued"

ConsumeResult ==
    /\ phase = "queued"
    /\ result = "ready"
    /\ phase' = IF mapped \/ USE_FIXED THEN "returned" ELSE "assertion"
    /\ UNCHANGED <<mapped, result>>

Done ==
    /\ phase \in {"returned", "assertion"}
    /\ UNCHANGED vars

Next == ConsumeResult \/ Done
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ mapped \in BOOLEAN
    /\ result = "ready"
    /\ phase \in {"queued", "returned", "assertion"}

NoRawAssertion == phase # "assertion"
ResultDelivered == phase = "returned"

=============================================================================
