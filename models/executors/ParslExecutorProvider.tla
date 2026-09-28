--------------------------- MODULE ParslExecutorProvider ---------------------------
EXTENDS Naturals, Integers, FiniteSets, Sequences

(***************************************************************************
 * Focused HighThroughputExecutor/ExecutionProvider abstraction.
 *
 * Provider blocks, manager registration, worker slots, executor admission,
 * drain/recovery, provider failure, and block-granular scale-in are separate
 * transitions.  In particular, an active provider block does not imply that
 * the executor currently accepts a task submission.
 ***************************************************************************)

CONSTANTS TASKS, MANAGERS, WORKERS, BLOCKS,
          MANAGER_BLOCKS, WORKER_MANAGERS,
          MAX_BLOCKS, MIN_BLOCKS, MAX_SUBMISSIONS

ExecutorStates == {"down", "up", "draining", "failed"}
ProviderStates == {"none", "requested", "active", "failed", "cancelled"}
ManagerStates == {"unregistered", "registered", "failed"}
WorkerStates == {"offline", "idle", "busy", "failed"}
TaskStates == {"new", "queued", "running", "done", "lost"}

VARIABLES executorState, providerState, providerTarget, providerBlocks,
          managerState, workerState, taskState, taskWorker,
          submitCount, submitRejected, completed

vars == <<executorState, providerState, providerTarget, providerBlocks,
           managerState, workerState, taskState, taskWorker,
           submitCount, submitRejected, completed>>

ManagerBlock(m) == CHOOSE b \in BLOCKS : m \o ":" \o b \in MANAGER_BLOCKS
WorkerManager(w) == CHOOSE m \in MANAGERS : w \o ":" \o m \in WORKER_MANAGERS
RegisteredManagers == {m \in MANAGERS : managerState[m] = "registered"}
IdleWorkers == {w \in WORKERS : workerState[w] = "idle"}

Init ==
    /\ TASKS # {} /\ MANAGERS # {} /\ WORKERS # {} /\ BLOCKS # {}
    /\ MAX_BLOCKS >= MIN_BLOCKS
    /\ MIN_BLOCKS >= 0
    /\ MAX_SUBMISSIONS > 0
    /\ MANAGER_BLOCKS \subseteq {m \o ":" \o b : m \in MANAGERS, b \in BLOCKS}
    /\ WORKER_MANAGERS \subseteq {w \o ":" \o m : w \in WORKERS, m \in MANAGERS}
    /\ \A m \in MANAGERS : \E b \in BLOCKS : m \o ":" \o b \in MANAGER_BLOCKS
    /\ \A w \in WORKERS : \E m \in MANAGERS : w \o ":" \o m \in WORKER_MANAGERS
    /\ executorState = "down"
    /\ providerState = "none"
    /\ providerTarget = MIN_BLOCKS
    /\ providerBlocks = 0
    /\ managerState = [m \in MANAGERS |-> "unregistered"]
    /\ workerState = [w \in WORKERS |-> "offline"]
    /\ taskState = [t \in TASKS |-> "new"]
    /\ taskWorker = [t \in TASKS |-> "none"]
    /\ submitCount = [t \in TASKS |-> 0]
    /\ submitRejected = [t \in TASKS |-> FALSE]
    /\ completed = {}

StartExecutor ==
    /\ executorState = "down"
    /\ executorState' = "up"
    /\ UNCHANGED <<providerState, providerTarget, providerBlocks,
                    managerState, workerState, taskState, taskWorker,
                    submitCount, submitRejected, completed>>

RequestBlock ==
    /\ executorState \in {"up", "draining"}
    /\ providerTarget < MAX_BLOCKS
    /\ providerState \in {"none", "active", "failed", "cancelled"}
    /\ providerState' = "requested"
    /\ providerTarget' = providerTarget + 1
    /\ UNCHANGED <<executorState, providerBlocks, managerState, workerState,
                    taskState, taskWorker, submitCount, submitRejected, completed>>

AllocationSucceeds ==
    /\ providerState = "requested"
    /\ providerBlocks < providerTarget
    /\ providerBlocks < MAX_BLOCKS
    /\ providerState' = "active"
    /\ providerBlocks' = providerBlocks + 1
    /\ UNCHANGED <<executorState, providerTarget, managerState, workerState,
                    taskState, taskWorker, submitCount, submitRejected, completed>>

AllocationFails ==
    /\ providerState = "requested"
    /\ providerTarget' = providerBlocks
    /\ providerBlocks' = providerBlocks
    /\ providerState' = IF providerBlocks > 0 THEN "active" ELSE "failed"
    /\ executorState' = IF providerBlocks > 0 THEN executorState ELSE "failed"
    /\ UNCHANGED <<managerState, workerState, taskState, taskWorker,
                    submitCount, submitRejected, completed>>

RegisterManager(m) ==
    /\ providerState = "active"
    /\ providerBlocks > Cardinality(RegisteredManagers)
    /\ managerState[m] = "unregistered"
    /\ managerState' = [managerState EXCEPT ![m] = "registered"]
    /\ UNCHANGED <<executorState, providerState, providerTarget, providerBlocks,
                    workerState, taskState, taskWorker,
                    submitCount, submitRejected, completed>>

ReadyWorker(w) ==
    /\ workerState[w] = "offline"
    /\ managerState[WorkerManager(w)] = "registered"
    /\ workerState' = [workerState EXCEPT ![w] = "idle"]
    /\ UNCHANGED <<executorState, providerState, providerTarget, providerBlocks,
                    managerState, taskState, taskWorker,
                    submitCount, submitRejected, completed>>

SubmitTask(t) ==
    /\ taskState[t] = "new"
    /\ executorState = "up"
    /\ providerState = "active"
    /\ IdleWorkers # {}
    /\ submitCount[t] < MAX_SUBMISSIONS
    /\ taskState' = [taskState EXCEPT ![t] = "queued"]
    /\ submitCount' = [submitCount EXCEPT ![t] = @ + 1]
    /\ submitRejected' = [submitRejected EXCEPT ![t] = FALSE]
    /\ UNCHANGED <<executorState, providerState, providerTarget, providerBlocks,
                    managerState, workerState, taskWorker, completed>>

RejectSubmit(t) ==
    /\ taskState[t] = "new"
    /\ submitCount[t] < MAX_SUBMISSIONS
    /\ executorState # "up" \/ providerState # "active" \/ IdleWorkers = {}
    /\ submitCount' = [submitCount EXCEPT ![t] = @ + 1]
    /\ submitRejected' = [submitRejected EXCEPT ![t] = TRUE]
    /\ UNCHANGED <<executorState, providerState, providerTarget, providerBlocks,
                    managerState, workerState, taskState, taskWorker, completed>>

RetryRejectedSubmit(t) ==
    /\ submitRejected[t]
    /\ taskState[t] = "new"
    /\ submitRejected' = [submitRejected EXCEPT ![t] = FALSE]
    /\ UNCHANGED <<executorState, providerState, providerTarget, providerBlocks,
                    managerState, workerState, taskState, taskWorker,
                    submitCount, completed>>

DispatchTask(t, w) ==
    /\ taskState[t] = "queued"
    /\ workerState[w] = "idle"
    /\ managerState[WorkerManager(w)] = "registered"
    /\ taskState' = [taskState EXCEPT ![t] = "running"]
    /\ taskWorker' = [taskWorker EXCEPT ![t] = w]
    /\ workerState' = [workerState EXCEPT ![w] = "busy"]
    /\ UNCHANGED <<executorState, providerState, providerTarget, providerBlocks,
                    managerState, submitCount, submitRejected, completed>>

CompleteTask(t) ==
    /\ taskState[t] = "running"
    /\ taskState' = [taskState EXCEPT ![t] = "done"]
    /\ workerState' = [workerState EXCEPT ![taskWorker[t]] = "idle"]
    /\ completed' = completed \cup {t}
    /\ UNCHANGED <<executorState, providerState, providerTarget, providerBlocks,
                    managerState, taskWorker, submitCount, submitRejected>>

DrainExecutor ==
    /\ executorState = "up"
    /\ executorState' = "draining"
    /\ UNCHANGED <<providerState, providerTarget, providerBlocks,
                    managerState, workerState, taskState, taskWorker,
                    submitCount, submitRejected, completed>>

RecoverExecutor ==
    /\ executorState \in {"draining", "failed"}
    /\ providerState = "active"
    /\ executorState' = "up"
    /\ UNCHANGED <<providerState, providerTarget, providerBlocks,
                    managerState, workerState, taskState, taskWorker,
                    submitCount, submitRejected, completed>>

FailProvider ==
    /\ providerState = "active"
    /\ providerBlocks > 0
    /\ providerState' = "failed"
    /\ providerBlocks' = 0
    /\ providerTarget' = 0
    /\ executorState' = "failed"
    /\ managerState' = [m \in MANAGERS |->
          IF managerState[m] = "registered" THEN "failed" ELSE managerState[m]]
    /\ workerState' = [w \in WORKERS |->
          IF workerState[w] \in {"idle", "busy"} THEN "failed" ELSE workerState[w]]
    /\ taskState' = [t \in TASKS |->
          IF taskState[t] = "running" THEN "lost"
          ELSE IF taskState[t] = "queued" THEN "new" ELSE taskState[t]]
    /\ submitRejected' = [t \in TASKS |->
          IF taskState[t] = "queued" THEN TRUE ELSE submitRejected[t]]
    /\ UNCHANGED <<completed, taskWorker, submitCount>>

CancelAllocation(m) ==
    /\ providerState = "active"
    /\ providerBlocks > MIN_BLOCKS
    /\ managerState[m] = "registered"
    /\ workerState[CHOOSE w \in WORKERS : WorkerManager(w) = m] = "idle"
    /\ providerBlocks' = providerBlocks - 1
    /\ providerTarget' = providerTarget - 1
    /\ providerState' = IF providerBlocks - 1 = 0 THEN "cancelled" ELSE "active"
    /\ executorState' = IF providerBlocks - 1 = 0 THEN "down" ELSE executorState
    /\ managerState' = [managerState EXCEPT ![m] = "failed"]
    /\ workerState' = [workerState EXCEPT
          ![CHOOSE w \in WORKERS : WorkerManager(w) = m] = "offline"]
    /\ taskState' = [t \in TASKS |->
          IF taskState[t] = "queued" THEN "new" ELSE taskState[t]]
    /\ submitRejected' = [t \in TASKS |->
          IF taskState[t] = "queued" THEN TRUE ELSE submitRejected[t]]
    /\ UNCHANGED <<taskWorker, submitCount, completed>>

Next ==
    \/ StartExecutor
    \/ RequestBlock
    \/ AllocationSucceeds
    \/ AllocationFails
    \/ \E m \in MANAGERS : RegisterManager(m)
    \/ \E w \in WORKERS : ReadyWorker(w)
    \/ \E t \in TASKS : SubmitTask(t) \/ RejectSubmit(t) \/ RetryRejectedSubmit(t)
    \/ \E t \in TASKS, w \in WORKERS : DispatchTask(t, w)
    \/ \E t \in TASKS : CompleteTask(t)
    \/ DrainExecutor
    \/ RecoverExecutor
    \/ FailProvider
    \/ \E m \in MANAGERS : CancelAllocation(m)
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ executorState \in ExecutorStates
    /\ providerState \in ProviderStates
    /\ providerTarget \in 0..MAX_BLOCKS
    /\ providerBlocks \in 0..MAX_BLOCKS
    /\ managerState \in [MANAGERS -> ManagerStates]
    /\ workerState \in [WORKERS -> WorkerStates]
    /\ taskState \in [TASKS -> TaskStates]
    /\ taskWorker \in [TASKS -> (WORKERS \cup {"none"})]
    /\ submitCount \in [TASKS -> 0..MAX_SUBMISSIONS]
    /\ submitRejected \in [TASKS -> BOOLEAN]
    /\ completed \subseteq TASKS

ProviderConsistency ==
    /\ providerBlocks <= providerTarget
    /\ providerBlocks <= MAX_BLOCKS
    /\ providerTarget >= MIN_BLOCKS
    /\ providerState = "active" => providerBlocks > 0
    /\ providerState = "failed" => providerBlocks = 0
    /\ providerState = "cancelled" => providerBlocks = 0

ExecutorAdmissionSafety ==
    \A t \in TASKS :
        taskState[t] \in {"queued", "running"}
        => executorState \in {"up", "draining"}

ManagerWorkerSafety ==
    /\ RegisteredManagers \subseteq MANAGERS
    /\ \A w \in WORKERS :
          workerState[w] \in {"idle", "busy"}
          => managerState[WorkerManager(w)] = "registered"
    /\ \A t \in TASKS :
          taskState[t] = "running" => taskWorker[t] \in WORKERS

SubmitSafety ==
    \A t \in TASKS :
        taskState[t] = "queued"
        => submitCount[t] > 0 /\ executorState \in {"up", "draining"}

TerminalTaskSafety ==
    \A t \in TASKS : taskState[t] = "done" => t \in completed

=============================================================================
