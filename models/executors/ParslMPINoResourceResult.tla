--------------------------- MODULE ParslMPINoResourceResult ---------------------------
EXTENDS Naturals

(***************************************************************************
 * MPITaskScheduler.get_result currently assumes every result task owns an
 * entry in _map_tasks_to_nodes.  A task without ``num_nodes`` is valid and is
 * deliberately not inserted into that map, but its result still enters the
 * result queue.  The current assert then aborts the scheduler.  USE_FIXED
 * models treating an unmapped result as a normal result with no node return.
 *************************************************************************** *)

CONSTANT USE_FIXED

VARIABLES resultKind, mapped, phase, schedulerAlive
vars == <<resultKind, mapped, phase, schedulerAlive>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ resultKind = "result"
    /\ mapped = FALSE
    /\ phase = "queued"
    /\ schedulerAlive = TRUE

ConsumeResult ==
    /\ phase = "queued" /\ resultKind = "result"
    /\ phase' = IF mapped \/ USE_FIXED THEN "returned" ELSE "asserted"
    /\ schedulerAlive' = IF mapped \/ USE_FIXED THEN TRUE ELSE FALSE
    /\ UNCHANGED <<resultKind, mapped>>

Done ==
    /\ phase \in {"returned", "asserted"}
    /\ UNCHANGED vars

Next == ConsumeResult \/ Done
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ resultKind = "result"
    /\ mapped \in BOOLEAN
    /\ phase \in {"queued", "returned", "asserted"}
    /\ schedulerAlive \in BOOLEAN

UnmappedResultSafety ==
    ~mapped /\ resultKind = "result" => phase # "asserted"

=============================================================================
