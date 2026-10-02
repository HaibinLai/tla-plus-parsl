--------------------------- MODULE ParslFluxLifecycle ---------------------------
EXTENDS Naturals, FiniteSets

(***************************************************************************
 * Compact composition model for FluxExecutor.
 *
 * A Parsl Future is kept distinct from the underlying Flux job and its
 * callback.  This exposes late/duplicate callbacks, callback result decoding,
 * cancellation, submission failure, and shutdown draining in one bounded
 * lifecycle.
 ***************************************************************************)

CONSTANT USE_FIXED
TASKS == {"T1", "T2"}
TaskStates == {"pending", "running", "done", "failed", "cancelled"}
ExecutorStates == {"running", "stopping", "stopped"}

VARIABLES active, state, callbackPending, collectorAlive, executorState, staleSeen
vars == <<active, state, callbackPending, collectorAlive, executorState, staleSeen>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ active = TASKS
    /\ state = [t \in TASKS |-> "pending"]
    /\ callbackPending = {}
    /\ collectorAlive = TRUE
    /\ executorState = "running"
    /\ staleSeen = FALSE

StartTask(t) ==
    /\ t \in active
    /\ state[t] = "pending"
    /\ state' = [state EXCEPT ![t] = "running"]
    /\ UNCHANGED <<active, callbackPending, collectorAlive, executorState, staleSeen>>

FluxFails(t) ==
    /\ t \in active
    /\ state[t] = "running"
    /\ state' = [state EXCEPT ![t] = "failed"]
    /\ active' = active \ {t}
    /\ UNCHANGED <<callbackPending, collectorAlive, executorState, staleSeen>>

FluxSucceeds(t) ==
    /\ t \in active
    /\ state[t] = "running"
    /\ callbackPending' = callbackPending \cup {t}
    /\ UNCHANGED <<active, state, collectorAlive, executorState, staleSeen>>

Callback(t, kind) ==
    /\ t \in TASKS
    /\ collectorAlive
    /\ kind \in {"valid", "failure"}
    /\ IF t \in callbackPending THEN
           /\ callbackPending' = callbackPending \ {t}
           /\ active' = active \ {t}
           /\ state' = [state EXCEPT ![t] = IF kind = "valid" THEN "done" ELSE "failed"]
           /\ UNCHANGED <<collectorAlive, executorState, staleSeen>>
       ELSE IF USE_FIXED THEN
           /\ staleSeen' = TRUE
           /\ UNCHANGED <<active, state, callbackPending, collectorAlive, executorState>>
       ELSE
           /\ collectorAlive' = FALSE
           /\ staleSeen' = TRUE
           /\ UNCHANGED <<active, state, callbackPending, executorState>>

Cancel(t) ==
    /\ t \in active
    /\ state[t] \in {"pending", "running"}
    /\ active' = active \ {t}
    /\ state' = [state EXCEPT ![t] = "cancelled"]
    /\ UNCHANGED <<callbackPending, collectorAlive, executorState, staleSeen>>

SubmissionFailure ==
    /\ collectorAlive
    /\ collectorAlive' = FALSE
    /\ state' = [t \in TASKS |-> IF t \in active THEN "failed" ELSE state[t]]
    /\ active' = {}
    /\ callbackPending' = {}
    /\ UNCHANGED <<executorState, staleSeen>>

RequestShutdown ==
    /\ executorState = "running"
    /\ executorState' = "stopping"
    /\ UNCHANGED <<active, state, callbackPending, collectorAlive, staleSeen>>

CollectorExits ==
    /\ collectorAlive
    /\ collectorAlive' = FALSE
    /\ state' = [t \in TASKS |-> IF t \in active THEN "failed" ELSE state[t]]
    /\ active' = {}
    /\ callbackPending' = {}
    /\ UNCHANGED <<executorState, staleSeen>>

FinishShutdown ==
    /\ executorState = "stopping"
    /\ ~collectorAlive
    /\ active = {}
    /\ executorState' = "stopped"
    /\ UNCHANGED <<active, state, callbackPending, collectorAlive, staleSeen>>

Next ==
    \/ \E t \in active : StartTask(t)
    \/ \E t \in active : FluxFails(t)
    \/ \E t \in active : FluxSucceeds(t)
    \/ \E t \in TASKS, kind \in {"valid", "failure"} : Callback(t, kind)
    \/ \E t \in active : Cancel(t)
    \/ SubmissionFailure
    \/ RequestShutdown
    \/ CollectorExits
    \/ FinishShutdown
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ active \subseteq TASKS
    /\ state \in [TASKS -> TaskStates]
    /\ callbackPending \subseteq TASKS
    /\ collectorAlive \in BOOLEAN
    /\ executorState \in ExecutorStates
    /\ staleSeen \in BOOLEAN

TerminalConsistency == \A t \in TASKS : state[t] \in {"done", "failed", "cancelled"} => t \notin active
ShutdownNoPending == executorState = "stopped" => active = {}
ShutdownTerminal == executorState = "stopped" => \A t \in TASKS : state[t] # "pending"
StaleDoesNotKillPeer == staleSeen /\ state["T2"] = "pending" => collectorAlive

=============================================================================
