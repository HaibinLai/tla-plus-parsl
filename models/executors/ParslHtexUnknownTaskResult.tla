--------------------------- MODULE ParslHtexUnknownTaskResult ---------------------------
EXTENDS Naturals

(***************************************************************************
 * HTEX result delivery for a task id no longer present in executor.tasks.
 *
 * A late result can arrive after retry cleanup, cancellation, or executor
 * teardown.  The current result worker pops the id unconditionally, so a
 * missing id raises KeyError and terminates the result loop.  The fixed branch
 * discards the stale result and continues processing the batch.
 *************************************************************************** *)

CONSTANT USE_FIXED

VARIABLES workerAlive, unknownPresent, livePresent, liveState, batchDone
vars == <<workerAlive, unknownPresent, livePresent, liveState, batchDone>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ workerAlive = TRUE
    /\ unknownPresent = TRUE
    /\ livePresent = TRUE
    /\ liveState = "pending"
    /\ batchDone = FALSE

ReceiveUnknownResult ==
    /\ workerAlive /\ unknownPresent
    /\ unknownPresent' = FALSE
    /\ workerAlive' = IF USE_FIXED THEN TRUE ELSE FALSE
    /\ UNCHANGED <<livePresent, liveState, batchDone>>

ReceiveLiveResult ==
    /\ workerAlive /\ livePresent
    /\ livePresent' = FALSE
    /\ liveState' = "done"
    /\ batchDone' = TRUE
    /\ UNCHANGED <<workerAlive, unknownPresent>>

Done ==
    /\ ~workerAlive \/ batchDone
    /\ UNCHANGED vars

Next == ReceiveUnknownResult \/ ReceiveLiveResult \/ Done
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ workerAlive \in BOOLEAN
    /\ unknownPresent \in BOOLEAN
    /\ livePresent \in BOOLEAN
    /\ liveState \in {"pending", "done"}
    /\ batchDone \in BOOLEAN

UnknownResultDoesNotKillWorker ==
    ~unknownPresent => workerAlive \/ liveState = "done"

LiveResultSafety ==
    batchDone => /\ liveState = "done" /\ ~livePresent

=============================================================================
