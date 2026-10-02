--------------------------- MODULE ParslWorkQueueLifecycle ---------------------------
EXTENDS Naturals, FiniteSets

(***************************************************************************
 * Compact composition model for WorkQueueExecutor.
 *
 * Two logical tasks are enough to expose the important collector boundary:
 * accepted tasks remain mapped until a report is decoded, duplicate/late
 * reports must not kill the collector, and shutdown must fail every remaining
 * Future before the executor reaches stopped.
 ***************************************************************************)

CONSTANT USE_FIXED
TASKS == {"T1", "T2"}

TaskStates == {"pending", "done", "failed"}
ExecutorStates == {"running", "stopping", "stopped"}

VARIABLES active, state, collectorAlive, executorState, staleSeen
vars == <<active, state, collectorAlive, executorState, staleSeen>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ active = TASKS
    /\ state = [t \in TASKS |-> "pending"]
    /\ collectorAlive = TRUE
    /\ executorState = "running"
    /\ staleSeen = FALSE

Report(t) ==
    /\ t \in TASKS
    /\ collectorAlive
    /\ IF t \in active THEN
           /\ active' = active \ {t}
           /\ state' = [state EXCEPT ![t] = "done"]
           /\ UNCHANGED <<collectorAlive, executorState, staleSeen>>
       ELSE IF USE_FIXED THEN
           /\ UNCHANGED <<active, state, collectorAlive, executorState>>
           /\ staleSeen' = TRUE
       ELSE
           /\ collectorAlive' = FALSE
           /\ staleSeen' = TRUE
           /\ UNCHANGED <<active, state, executorState>>

RequestShutdown ==
    /\ executorState = "running"
    /\ executorState' = "stopping"
    /\ UNCHANGED <<active, state, collectorAlive, staleSeen>>

CollectorExits ==
    /\ collectorAlive
    /\ collectorAlive' = FALSE
    /\ state' = [t \in TASKS |-> IF t \in active THEN "failed" ELSE state[t]]
    /\ active' = {}
    /\ UNCHANGED <<executorState, staleSeen>>

FinishShutdown ==
    /\ executorState = "stopping"
    /\ ~collectorAlive
    /\ active = {}
    /\ executorState' = "stopped"
    /\ UNCHANGED <<active, state, collectorAlive, staleSeen>>

Next ==
    \/ \E t \in TASKS : Report(t)
    \/ RequestShutdown
    \/ CollectorExits
    \/ FinishShutdown
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ active \subseteq TASKS
    /\ state \in [TASKS -> TaskStates]
    /\ collectorAlive \in BOOLEAN
    /\ executorState \in ExecutorStates
    /\ staleSeen \in BOOLEAN

ResultSafety == \A t \in TASKS : state[t] = "done" => t \notin active
ShutdownNoPending == executorState = "stopped" => active = {}
ShutdownTerminal == executorState = "stopped" => \A t \in TASKS : state[t] # "pending"
StaleDoesNotKillPeer == staleSeen /\ state["T2"] = "pending" => collectorAlive

=============================================================================
