--------------------------- MODULE ParslRadicalPilotLifecycle ---------------------------
EXTENDS Naturals, FiniteSets

(***************************************************************************
 * Compact composition model for RadicalPilotExecutor.
 *
 * Logical Futures are separated from RP task callbacks.  The model combines
 * submit, DONE/FAILED/CANCELED callback mapping, late callbacks, master
 * failure fan-out, bulk collector shutdown, and terminal Future cleanup.
 ***************************************************************************)

CONSTANT USE_FIXED
TASKS == {"T1", "T2"}
TaskStates == {"pending", "running", "done", "failed", "cancelled"}
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

StartTask(t) ==
    /\ t \in active
    /\ state[t] = "pending"
    /\ state' = [state EXCEPT ![t] = "running"]
    /\ UNCHANGED <<active, collectorAlive, executorState, staleSeen>>

Done(t) ==
    /\ t \in active
    /\ state[t] = "running"
    /\ active' = active \ {t}
    /\ state' = [state EXCEPT ![t] = "done"]
    /\ UNCHANGED <<collectorAlive, executorState, staleSeen>>

Failed(t) ==
    /\ t \in active
    /\ state[t] = "running"
    /\ active' = active \ {t}
    /\ state' = [state EXCEPT ![t] = "failed"]
    /\ UNCHANGED <<collectorAlive, executorState, staleSeen>>

Cancel(t) ==
    /\ t \in active
    /\ state[t] \in {"pending", "running"}
    /\ active' = active \ {t}
    /\ state' = [state EXCEPT ![t] = "cancelled"]
    /\ UNCHANGED <<collectorAlive, executorState, staleSeen>>

LateCallback(t) ==
    /\ t \in TASKS
    /\ collectorAlive
    /\ t \notin active
    /\ IF USE_FIXED THEN
           /\ staleSeen' = TRUE
           /\ UNCHANGED <<active, state, collectorAlive, executorState>>
       ELSE
           /\ collectorAlive' = FALSE
           /\ staleSeen' = TRUE
           /\ UNCHANGED <<active, state, executorState>>

MasterFails ==
    /\ collectorAlive
    /\ collectorAlive' = FALSE
    /\ state' = [t \in TASKS |-> IF t \in active THEN "failed" ELSE state[t]]
    /\ active' = {}
    /\ UNCHANGED <<executorState, staleSeen>>

RequestShutdown ==
    /\ executorState = "running"
    /\ executorState' = "stopping"
    /\ UNCHANGED <<active, state, collectorAlive, staleSeen>>

CollectorExits ==
    /\ collectorAlive
    /\ executorState = "stopping"
    /\ collectorAlive' = FALSE
    /\ IF USE_FIXED THEN
           /\ state' = [t \in TASKS |-> IF t \in active THEN "failed" ELSE state[t]]
           /\ active' = {}
       ELSE
           /\ UNCHANGED <<active, state>>
    /\ UNCHANGED <<executorState, staleSeen>>

FinishShutdown ==
    /\ executorState = "stopping"
    /\ ~collectorAlive
    /\ active = {}
    /\ executorState' = "stopped"
    /\ UNCHANGED <<active, state, collectorAlive, staleSeen>>

Next ==
    \/ \E t \in active : StartTask(t)
    \/ \E t \in active : Done(t)
    \/ \E t \in active : Failed(t)
    \/ \E t \in active : Cancel(t)
    \/ \E t \in TASKS : LateCallback(t)
    \/ MasterFails
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

TerminalConsistency == \A t \in TASKS : state[t] \in {"done", "failed", "cancelled"} => t \notin active
ShutdownNoPending == executorState = "stopped" => active = {}
ShutdownTerminal == executorState = "stopped" => \A t \in TASKS : state[t] # "pending"
StaleDoesNotKillPeer == staleSeen /\ state["T2"] = "pending" => collectorAlive

=============================================================================
