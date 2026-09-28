--------------------------- MODULE ParslRadicalPilotBulkShutdown ---------------------------
EXTENDS Naturals

(***************************************************************************
 * RadicalPilotExecutor bulk mode collects translated RP tasks in a queue.
 * shutdown sets _terminate before joining _bulk_thread.  The current collector
 * exits its outer loop immediately and leaves queued tasks/Futures pending.
 * USE_FIXED flushes the queue before allowing the collector to exit.
 *************************************************************************** *)

CONSTANT USE_FIXED

VARIABLES executorState, collectorState, terminate, queued, futureState
vars == <<executorState, collectorState, terminate, queued, futureState>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ executorState = "running"
    /\ collectorState = "active"
    /\ terminate = FALSE
    /\ queued = 1
    /\ futureState = "pending"

RequestShutdown ==
    /\ executorState = "running"
    /\ executorState' = "stopping"
    /\ terminate' = TRUE
    /\ UNCHANGED <<collectorState, queued, futureState>>

FlushBulk ==
    /\ collectorState = "active"
    /\ terminate
    /\ USE_FIXED
    /\ queued > 0
    /\ queued' = 0
    /\ futureState' = "submitted"
    /\ collectorState' = "exited"
    /\ UNCHANGED <<executorState, terminate>>

DropBulk ==
    /\ collectorState = "active"
    /\ terminate
    /\ ~USE_FIXED
    /\ collectorState' = "exited"
    /\ UNCHANGED <<executorState, terminate, queued, futureState>>

FinishShutdown ==
    /\ executorState = "stopping"
    /\ collectorState = "exited"
    /\ executorState' = "stopped"
    /\ futureState' = IF USE_FIXED THEN futureState ELSE futureState
    /\ UNCHANGED <<collectorState, terminate, queued>>

Done ==
    /\ executorState = "stopped"
    /\ UNCHANGED vars

Next == RequestShutdown \/ FlushBulk \/ DropBulk \/ FinishShutdown \/ Done
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ executorState \in {"running", "stopping", "stopped"}
    /\ collectorState \in {"active", "exited"}
    /\ terminate \in BOOLEAN
    /\ queued \in 0..1
    /\ futureState \in {"pending", "submitted"}

ShutdownFutureSafety ==
    executorState = "stopped" => futureState = "submitted"

QueueDrainSafety ==
    executorState = "stopped" => queued = 0

=============================================================================
