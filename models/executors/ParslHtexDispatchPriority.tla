--------------------------- MODULE ParslHtexDispatchPriority ---------------------------
EXTENDS Naturals, Sequences, FiniteSets

(***************************************************************************
 * HTEX pending-task priority and manager capacity.
 *
 * Interchange stores (-priority, -task_id, message) in a SortedList and pops
 * from the end.  Lower numeric priority is therefore dispatched first, with
 * task id providing a deterministic tie-breaker.  A manager is dispatched
 * only while active, non-draining, and below max capacity.
 ***************************************************************************)

TASKS == {1, 2, 3}
MAX_CAPACITY == 2
PRIORITY == [t \in TASKS |-> IF t = 1 THEN 1 ELSE IF t = 2 THEN 5 ELSE 100]
SetMin(S) == CHOOSE x \in S : \A y \in S : x <= y

VARIABLES queued, sent, inFlight, managerActive, draining,
          dispatchWhileDraining
vars == <<queued, sent, inFlight, managerActive, draining,
           dispatchWhileDraining>>

Init ==
    /\ queued = TASKS
    /\ sent = <<>>
    /\ inFlight = 0
    /\ managerActive = TRUE
    /\ draining = FALSE
    /\ dispatchWhileDraining = FALSE

Dispatch(t) ==
    /\ t \in queued
    /\ managerActive
    /\ ~draining
    /\ inFlight < MAX_CAPACITY
    /\ PRIORITY[t] = SetMin({PRIORITY[x] : x \in queued})
    /\ queued' = queued \ {t}
    /\ sent' = Append(sent, t)
    /\ inFlight' = inFlight + 1
    /\ dispatchWhileDraining' = dispatchWhileDraining \/ draining
    /\ UNCHANGED <<managerActive, draining>>

Complete ==
    /\ inFlight > 0
    /\ inFlight' = inFlight - 1
    /\ UNCHANGED <<queued, sent, managerActive, draining,
                    dispatchWhileDraining>>

Drain ==
    /\ managerActive
    /\ ~draining
    /\ draining' = TRUE
    /\ UNCHANGED <<queued, sent, inFlight, managerActive,
                    dispatchWhileDraining>>

Recover ==
    /\ managerActive
    /\ draining
    /\ draining' = FALSE
    /\ UNCHANGED <<queued, sent, inFlight, managerActive,
                    dispatchWhileDraining>>

FailManager ==
    /\ managerActive
    /\ managerActive' = FALSE
    /\ inFlight' = 0
    /\ UNCHANGED <<queued, sent, draining, dispatchWhileDraining>>

Next ==
    \/ \E t \in TASKS : Dispatch(t)
    \/ Complete
    \/ Drain
    \/ Recover
    \/ FailManager
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ queued \subseteq TASKS
    /\ sent \in Seq(TASKS)
    /\ inFlight \in 0..MAX_CAPACITY
    /\ managerActive \in BOOLEAN
    /\ draining \in BOOLEAN
    /\ dispatchWhileDraining \in BOOLEAN

PriorityOrder ==
    \A i, j \in 1..Len(sent) :
        i < j => PRIORITY[sent[i]] <= PRIORITY[sent[j]]

CapacitySafety ==
    inFlight <= MAX_CAPACITY

QueueAccounting ==
    Cardinality(queued) + Len(sent) <= Cardinality(TASKS)

DrainAdmissionSafety ==
    dispatchWhileDraining = FALSE

FailureCleanupSafety ==
    ~managerActive => inFlight = 0

=============================================================================
