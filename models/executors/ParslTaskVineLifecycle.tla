--------------------------- MODULE ParslTaskVineLifecycle ---------------------------
EXTENDS Naturals, FiniteSets

(***************************************************************************
 * Compact composition model for TaskVineExecutor.
 *
 * The manager, collector, task map, result reports, and shutdown are kept in
 * one small state machine.  A duplicate report is a stale physical event: it
 * must not terminate collection or fail an unrelated logical task.
 ***************************************************************************)

CONSTANT USE_FIXED
TASKS == {"T1", "T2"}
TaskStates == {"pending", "done", "failed"}
ExecutorStates == {"running", "stopping", "stopped"}

VARIABLES active, state, managerUp, collectorAlive, executorState, staleSeen
vars == <<active, state, managerUp, collectorAlive, executorState, staleSeen>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ active = TASKS
    /\ state = [t \in TASKS |-> "pending"]
    /\ managerUp = TRUE
    /\ collectorAlive = TRUE
    /\ executorState = "running"
    /\ staleSeen = FALSE

Report(t) ==
    /\ t \in TASKS
    /\ managerUp
    /\ collectorAlive
    /\ IF t \in active THEN
           /\ active' = active \ {t}
           /\ state' = [state EXCEPT ![t] = "done"]
           /\ UNCHANGED <<managerUp, collectorAlive, executorState, staleSeen>>
       ELSE IF USE_FIXED THEN
           /\ UNCHANGED <<active, state, managerUp, collectorAlive, executorState>>
           /\ staleSeen' = TRUE
       ELSE
           /\ collectorAlive' = FALSE
           /\ staleSeen' = TRUE
           /\ UNCHANGED <<active, state, managerUp, executorState>>

ManagerFails ==
    /\ managerUp
    /\ managerUp' = FALSE
    /\ collectorAlive' = FALSE
    /\ state' = [t \in TASKS |-> IF t \in active THEN "failed" ELSE state[t]]
    /\ active' = {}
    /\ UNCHANGED <<executorState, staleSeen>>

RequestShutdown ==
    /\ executorState = "running"
    /\ executorState' = "stopping"
    /\ UNCHANGED <<active, state, managerUp, collectorAlive, staleSeen>>

CollectorExits ==
    /\ collectorAlive
    /\ collectorAlive' = FALSE
    /\ state' = [t \in TASKS |-> IF t \in active THEN "failed" ELSE state[t]]
    /\ active' = {}
    /\ UNCHANGED <<managerUp, executorState, staleSeen>>

FinishShutdown ==
    /\ executorState = "stopping"
    /\ ~collectorAlive
    /\ active = {}
    /\ executorState' = "stopped"
    /\ UNCHANGED <<active, state, managerUp, collectorAlive, staleSeen>>

Next ==
    \/ \E t \in TASKS : Report(t)
    \/ ManagerFails
    \/ RequestShutdown
    \/ CollectorExits
    \/ FinishShutdown
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ active \subseteq TASKS
    /\ state \in [TASKS -> TaskStates]
    /\ managerUp \in BOOLEAN
    /\ collectorAlive \in BOOLEAN
    /\ executorState \in ExecutorStates
    /\ staleSeen \in BOOLEAN

ResultSafety == \A t \in TASKS : state[t] = "done" => t \notin active
ShutdownNoPending == executorState = "stopped" => active = {}
ShutdownTerminal == executorState = "stopped" => \A t \in TASKS : state[t] # "pending"
StaleDoesNotKillPeer == staleSeen /\ state["T2"] = "pending" => collectorAlive

=============================================================================
