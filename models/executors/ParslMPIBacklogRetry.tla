--------------------------- MODULE ParslMPIBacklogRetry ---------------------------
EXTENDS Naturals

(***************************************************************************
 * MPITaskScheduler._schedule_backlog_tasks removes one backlog item and
 * calls put_task.  If resources are still unavailable, put_task requeues the
 * item; the current helper nevertheless recurses unconditionally and retries
 * forever in the same call.  USE_FIXED stops the scheduling pass when the
 * head item cannot fit, leaving it queued for a later result.
 *************************************************************************** *)

CONSTANT USE_FIXED

VARIABLES freeNodes, requiredNodes, backlog, phase, attempts
vars == <<freeNodes, requiredNodes, backlog, phase, attempts>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ freeNodes = 1
    /\ requiredNodes = 2
    /\ backlog = 1
    /\ phase = "queued"
    /\ attempts = 0

ScheduleHead ==
    /\ phase \in {"queued", "retrying"}
    /\ backlog = 1
    /\ freeNodes < requiredNodes
    /\ attempts' = attempts + 1
    /\ backlog' = 1
    /\ IF USE_FIXED
          THEN phase' = "waiting"
          ELSE IF attempts >= 2 THEN phase' = "overflow" ELSE phase' = "retrying"
    /\ UNCHANGED <<freeNodes, requiredNodes>>

ResourceReturn ==
    /\ phase = "waiting"
    /\ freeNodes' = requiredNodes
    /\ UNCHANGED <<requiredNodes, backlog, phase, attempts>>

Done ==
    /\ phase \in {"waiting", "overflow"}
    /\ UNCHANGED vars

Next == ScheduleHead \/ ResourceReturn \/ Done
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ freeNodes \in Nat
    /\ requiredNodes \in Nat
    /\ backlog \in 0..1
    /\ phase \in {"queued", "retrying", "waiting", "overflow"}
    /\ attempts \in Nat

NoRecursiveOverflow == phase # "overflow"

=============================================================================
