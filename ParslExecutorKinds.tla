--------------------------- MODULE ParslExecutorKinds ---------------------------
EXTENDS Naturals, FiniteSets

(***************************************************************************
 * Executor contract matrix.
 *
 * This model distinguishes provider-free ThreadPool execution from
 * provider-backed HTEX/MPI/workqueue-style execution.  It records which
 * paths need manager registration, which paths can submit resource requests,
 * and how drain/failure affects admission.
 ***************************************************************************)

CONSTANTS EXECUTORS, LOCAL_EXECUTORS, HTEX_EXECUTORS,
          MPI_EXECUTORS, WORKQUEUE_EXECUTORS,
          MAX_LOCAL_SLOTS, MAX_REMOTE_SLOTS, MAX_TASKS

ExecutorStates == {"down", "up", "draining", "failed"}
ProviderStates == {"none", "active", "failed"}
ProviderExecutors == HTEX_EXECUTORS \cup MPI_EXECUTORS \cup WORKQUEUE_EXECUTORS
ManagerExecutors == HTEX_EXECUTORS \cup WORKQUEUE_EXECUTORS
ManagerRequired(e) == e \in ManagerExecutors
ProviderRequired(e) == e \in ProviderExecutors
MonitorResources(e) == e \in HTEX_EXECUTORS \cup WORKQUEUE_EXECUTORS
ResourceSpecUnsupported(e) == e \in LOCAL_EXECUTORS \cup MPI_EXECUTORS
LostLimit == MAX_TASKS + MAX_REMOTE_SLOTS

VARIABLES executorState, providerState, managerReady, workerSlots,
          queued, running, lost, submitRejected, resourceRequest

vars == <<executorState, providerState, managerReady, workerSlots,
           queued, running, lost, submitRejected, resourceRequest>>

Init ==
    /\ EXECUTORS # {}
    /\ LOCAL_EXECUTORS \cup ProviderExecutors = EXECUTORS
    /\ LOCAL_EXECUTORS \cap ProviderExecutors = {}
    /\ HTEX_EXECUTORS \cap MPI_EXECUTORS = {}
    /\ HTEX_EXECUTORS \cap WORKQUEUE_EXECUTORS = {}
    /\ MPI_EXECUTORS \cap WORKQUEUE_EXECUTORS = {}
    /\ MAX_LOCAL_SLOTS > 0
    /\ MAX_REMOTE_SLOTS > 0
    /\ MAX_TASKS > 0
    /\ executorState = [e \in EXECUTORS |-> "down"]
    /\ providerState = [e \in EXECUTORS |->
          IF ProviderRequired(e) THEN "none" ELSE "none"]
    /\ managerReady = [e \in EXECUTORS |-> FALSE]
    /\ workerSlots = [e \in EXECUTORS |-> 0]
    /\ queued = [e \in EXECUTORS |-> 0]
    /\ running = [e \in EXECUTORS |-> 0]
    /\ lost = [e \in EXECUTORS |-> 0]
    /\ submitRejected = [e \in EXECUTORS |-> 0]
    /\ resourceRequest = [e \in EXECUTORS |-> FALSE]

StartExecutor(e) ==
    /\ executorState[e] = "down"
    /\ executorState' = [executorState EXCEPT ![e] = "up"]
    /\ managerReady' = [managerReady EXCEPT ![e] = ~ProviderRequired(e)]
    /\ workerSlots' = [workerSlots EXCEPT
          ![e] = IF ProviderRequired(e) THEN 0 ELSE MAX_LOCAL_SLOTS]
    /\ UNCHANGED <<providerState, queued, running,
                    lost, submitRejected, resourceRequest>>

ProvisionProvider(e) ==
    /\ ProviderRequired(e)
    /\ executorState[e] = "up"
    /\ providerState[e] = "none"
    /\ providerState' = [providerState EXCEPT ![e] = "active"]
    /\ managerReady' = [managerReady EXCEPT ![e] = ~ManagerRequired(e)]
    /\ workerSlots' = [workerSlots EXCEPT ![e] =
          IF ManagerRequired(e) THEN 0 ELSE MAX_REMOTE_SLOTS]
    /\ UNCHANGED <<executorState, queued, running, lost,
                    submitRejected, resourceRequest>>

RegisterManager(e) ==
    /\ ManagerRequired(e)
    /\ executorState[e] = "up"
    /\ providerState[e] = "active"
    /\ ~managerReady[e]
    /\ managerReady' = [managerReady EXCEPT ![e] = TRUE]
    /\ workerSlots' = [workerSlots EXCEPT ![e] = MAX_REMOTE_SLOTS]
    /\ UNCHANGED <<executorState, providerState, queued, running,
                    lost, submitRejected, resourceRequest>>

SetResourceRequest(e) ==
    /\ ~resourceRequest[e]
    /\ queued[e] = 0
    /\ running[e] = 0
    /\ resourceRequest' = [resourceRequest EXCEPT ![e] = TRUE]
    /\ UNCHANGED <<executorState, providerState, managerReady, workerSlots,
                    queued, running, lost, submitRejected>>

ClearResourceRequest(e) ==
    /\ resourceRequest[e]
    /\ resourceRequest' = [resourceRequest EXCEPT ![e] = FALSE]
    /\ UNCHANGED <<executorState, providerState, managerReady, workerSlots,
                    queued, running, lost, submitRejected>>

Submit(e) ==
    /\ executorState[e] = "up"
    /\ (ProviderRequired(e) => providerState[e] = "active")
    /\ managerReady[e]
    /\ workerSlots[e] > 0
    /\ ~ (resourceRequest[e] /\ ResourceSpecUnsupported(e))
    /\ queued[e] < MAX_TASKS
    /\ queued' = [queued EXCEPT ![e] = @ + 1]
    /\ workerSlots' = [workerSlots EXCEPT ![e] = @ - 1]
    /\ UNCHANGED <<executorState, providerState, managerReady,
                    running, lost, submitRejected, resourceRequest>>

RejectSubmit(e) ==
    /\ submitRejected[e] < MAX_TASKS
    /\ executorState[e] # "up"
        \/ ~managerReady[e]
        \/ workerSlots[e] = 0
        \/ (resourceRequest[e] /\ ResourceSpecUnsupported(e))
        \/ (ProviderRequired(e) /\ providerState[e] # "active")
    /\ submitRejected' = [submitRejected EXCEPT ![e] = @ + 1]
    /\ UNCHANGED <<executorState, providerState, managerReady, workerSlots,
                    queued, running, lost, resourceRequest>>

StartQueued(e) ==
    /\ queued[e] > 0
    /\ executorState[e] \in {"up", "draining"}
    /\ queued' = [queued EXCEPT ![e] = @ - 1]
    /\ running' = [running EXCEPT ![e] = @ + 1]
    /\ UNCHANGED <<executorState, providerState, managerReady, workerSlots,
                    lost, submitRejected, resourceRequest>>

Complete(e) ==
    /\ running[e] > 0
    /\ workerSlots[e] < IF ProviderRequired(e) THEN MAX_REMOTE_SLOTS ELSE MAX_LOCAL_SLOTS
    /\ running' = [running EXCEPT ![e] = @ - 1]
    /\ workerSlots' = [workerSlots EXCEPT ![e] = @ + 1]
    /\ UNCHANGED <<executorState, providerState, managerReady, queued,
                    lost, submitRejected, resourceRequest>>

Drain(e) ==
    /\ executorState[e] = "up"
    /\ executorState' = [executorState EXCEPT ![e] = "draining"]
    /\ UNCHANGED <<providerState, managerReady, workerSlots, queued,
                    running, lost, submitRejected, resourceRequest>>

Recover(e) ==
    /\ executorState[e] \in {"draining", "failed"}
    /\ (ProviderRequired(e) => providerState[e] = "active")
    /\ executorState' = [executorState EXCEPT ![e] = "up"]
    /\ managerReady' = [managerReady EXCEPT ![e] =
          IF ManagerRequired(e) THEN managerReady[e] ELSE TRUE]
    /\ workerSlots' = [workerSlots EXCEPT ![e] =
          IF running[e] > 0 THEN workerSlots[e]
          ELSE IF ProviderRequired(e)
               THEN IF ManagerRequired(e)
                    THEN IF managerReady[e] THEN MAX_REMOTE_SLOTS ELSE 0
                    ELSE MAX_REMOTE_SLOTS
               ELSE MAX_LOCAL_SLOTS]
    /\ UNCHANGED <<providerState, queued,
                    running, lost, submitRejected, resourceRequest>>

FailExecutor(e) ==
    /\ executorState[e] \in {"up", "draining"}
    /\ executorState' = [executorState EXCEPT ![e] = "failed"]
    /\ managerReady' = [managerReady EXCEPT ![e] = FALSE]
    /\ lost' = [lost EXCEPT ![e] =
          IF @ + queued[e] + running[e] > LostLimit
          THEN LostLimit ELSE @ + queued[e] + running[e]]
    /\ queued' = [queued EXCEPT ![e] = 0]
    /\ running' = [running EXCEPT ![e] = 0]
    /\ workerSlots' = [workerSlots EXCEPT ![e] = 0]
    /\ UNCHANGED <<providerState, submitRejected, resourceRequest>>

FailProvider(e) ==
    /\ ProviderRequired(e)
    /\ providerState[e] = "active"
    /\ providerState' = [providerState EXCEPT ![e] = "failed"]
    /\ executorState' = [executorState EXCEPT ![e] = "failed"]
    /\ managerReady' = [managerReady EXCEPT ![e] = FALSE]
    /\ lost' = [lost EXCEPT ![e] =
          IF @ + queued[e] + running[e] > LostLimit
          THEN LostLimit ELSE @ + queued[e] + running[e]]
    /\ queued' = [queued EXCEPT ![e] = 0]
    /\ running' = [running EXCEPT ![e] = 0]
    /\ workerSlots' = [workerSlots EXCEPT ![e] = 0]
    /\ UNCHANGED <<submitRejected, resourceRequest>>

Next ==
    \/ \E e \in EXECUTORS : StartExecutor(e)
    \/ \E e \in EXECUTORS : ProvisionProvider(e)
    \/ \E e \in EXECUTORS : RegisterManager(e)
    \/ \E e \in EXECUTORS : SetResourceRequest(e) \/ ClearResourceRequest(e)
    \/ \E e \in EXECUTORS : Submit(e) \/ RejectSubmit(e)
    \/ \E e \in EXECUTORS : StartQueued(e) \/ Complete(e)
    \/ \E e \in EXECUTORS : Drain(e) \/ Recover(e)
    \/ \E e \in EXECUTORS : FailExecutor(e) \/ FailProvider(e)
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ executorState \in [EXECUTORS -> ExecutorStates]
    /\ providerState \in [EXECUTORS -> ProviderStates]
    /\ managerReady \in [EXECUTORS -> BOOLEAN]
    /\ workerSlots \in [EXECUTORS -> 0..MAX_REMOTE_SLOTS]
    /\ queued \in [EXECUTORS -> 0..MAX_TASKS]
    /\ running \in [EXECUTORS -> 0..(MAX_TASKS + MAX_REMOTE_SLOTS)]
    /\ lost \in [EXECUTORS -> 0..LostLimit]
    /\ submitRejected \in [EXECUTORS -> 0..MAX_TASKS]
    /\ resourceRequest \in [EXECUTORS -> BOOLEAN]

ContractSafety ==
    /\ \A e \in LOCAL_EXECUTORS : providerState[e] = "none"
    /\ \A e \in ManagerExecutors : managerReady[e] => providerState[e] = "active"
    /\ \A e \in ManagerExecutors : ~managerReady[e] => workerSlots[e] = 0
    /\ \A e \in MPI_EXECUTORS : resourceRequest[e]
          => queued[e] = 0 /\ running[e] = 0

AdmissionSafety ==
    \A e \in EXECUTORS :
        queued[e] > 0 \/ running[e] > 0
        => executorState[e] \in {"up", "draining"}

DrainSafety ==
    \A e \in EXECUTORS : executorState[e] = "draining"
        => queued[e] <= MAX_TASKS

FailureCleanupSafety ==
    \A e \in EXECUTORS : executorState[e] = "failed"
        => queued[e] = 0 /\ running[e] = 0 /\ workerSlots[e] = 0

ResourceSpecSafety ==
    \A e \in LOCAL_EXECUTORS \cup MPI_EXECUTORS :
        resourceRequest[e] => queued[e] = 0 /\ running[e] = 0

=============================================================================
