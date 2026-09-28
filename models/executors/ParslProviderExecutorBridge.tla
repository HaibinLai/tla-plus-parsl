--------------------------- MODULE ParslProviderExecutorBridge ---------------------------
EXTENDS Naturals, FiniteSets

(***************************************************************************
 * Cross-component provider/executor model.
 *
 * A provider job is the pilot/block, while managerReady and workerSlots are
 * executor-side observations of that job.  Terminal provider observations
 * therefore have to revoke executor admission before queued or running work
 * can be considered lost.
 ***************************************************************************)

CONSTANTS MAX_SLOTS, MAX_TASKS, MAX_FAILURES

ProviderJobStates == {"down", "pending", "running", "completed", "failed",
                      "timeout", "missing", "unknown", "cancelled"}
ExecutorStates == {"down", "up", "draining", "failed"}

VARIABLES providerJob, executorState, managerReady, workerSlots,
          queued, running, lost, submitRejected, statusFailures
vars == <<providerJob, executorState, managerReady, workerSlots,
          queued, running, lost, submitRejected, statusFailures>>

Init ==
    /\ MAX_SLOTS > 0
    /\ MAX_TASKS > 0
    /\ MAX_FAILURES > 0
    /\ providerJob = "down"
    /\ executorState = "down"
    /\ managerReady = FALSE
    /\ workerSlots = 0
    /\ queued = 0
    /\ running = 0
    /\ lost = 0
    /\ submitRejected = 0
    /\ statusFailures = 0

StartExecutor ==
    /\ executorState = "down"
    /\ executorState' = "up"
    /\ UNCHANGED <<providerJob, managerReady, workerSlots,
                    queued, running, lost, submitRejected, statusFailures>>

RequestBlock ==
    /\ executorState = "up"
    /\ providerJob = "down"
    /\ providerJob' = "pending"
    /\ managerReady' = FALSE
    /\ workerSlots' = 0
    /\ UNCHANGED <<executorState, queued, running, lost,
                    submitRejected, statusFailures>>

ProviderStarts ==
    /\ providerJob = "pending"
    /\ providerJob' = "running"
    /\ UNCHANGED <<executorState, managerReady, workerSlots,
                    queued, running, lost, submitRejected, statusFailures>>

RegisterManager ==
    /\ executorState = "up"
    /\ providerJob = "running"
    /\ ~managerReady
    /\ managerReady' = TRUE
    /\ workerSlots' = MAX_SLOTS
    /\ UNCHANGED <<providerJob, executorState, queued, running,
                    lost, submitRejected, statusFailures>>

SubmitTask ==
    /\ executorState = "up"
    /\ managerReady
    /\ workerSlots > 0
    /\ queued < MAX_TASKS
    /\ queued' = queued + 1
    /\ workerSlots' = workerSlots - 1
    /\ UNCHANGED <<providerJob, executorState, managerReady, running,
                    lost, submitRejected, statusFailures>>

RejectTask ==
    /\ submitRejected < MAX_FAILURES
    /\ (executorState # "up" \/ ~managerReady \/ workerSlots = 0
        \/ providerJob # "running")
    /\ submitRejected' = submitRejected + 1
    /\ UNCHANGED <<providerJob, executorState, managerReady, workerSlots,
                    queued, running, lost, statusFailures>>

StartQueued ==
    /\ queued > 0
    /\ executorState \in {"up", "draining"}
    /\ queued' = queued - 1
    /\ running' = running + 1
    /\ UNCHANGED <<providerJob, executorState, managerReady, workerSlots,
                    lost, submitRejected, statusFailures>>

ObserveRunning ==
    /\ providerJob \in {"pending", "unknown"}
    /\ providerJob' = "running"
    /\ UNCHANGED <<executorState, managerReady, workerSlots,
                    queued, running, lost, submitRejected, statusFailures>>

ObserveUnknown ==
    /\ providerJob = "running"
    /\ providerJob' = "unknown"
    /\ UNCHANGED <<executorState, managerReady, workerSlots,
                    queued, running, lost, submitRejected, statusFailures>>

StatusFailure ==
    /\ statusFailures < MAX_FAILURES
    /\ statusFailures' = statusFailures + 1
    /\ UNCHANGED <<providerJob, executorState, managerReady, workerSlots,
                    queued, running, lost, submitRejected>>

ProviderTerminal(kind) ==
    /\ providerJob \in {"pending", "running", "unknown"}
    /\ kind \in {"completed", "failed", "timeout", "missing", "cancelled"}
    /\ providerJob' = kind
    /\ executorState' = "failed"
    /\ managerReady' = FALSE
    /\ workerSlots' = 0
    /\ lost' = lost + queued + running
    /\ queued' = 0
    /\ running' = 0
    /\ UNCHANGED <<submitRejected, statusFailures>>

Drain ==
    /\ executorState = "up"
    /\ executorState' = "draining"
    /\ UNCHANGED <<providerJob, managerReady, workerSlots,
                    queued, running, lost, submitRejected, statusFailures>>

Recover ==
    /\ executorState = "draining"
    /\ providerJob = "running"
    /\ executorState' = "up"
    /\ UNCHANGED <<providerJob, managerReady, workerSlots,
                    queued, running, lost, submitRejected, statusFailures>>

Next ==
    \/ StartExecutor
    \/ RequestBlock
    \/ ProviderStarts
    \/ RegisterManager
    \/ SubmitTask
    \/ RejectTask
    \/ StartQueued
    \/ ObserveRunning
    \/ ObserveUnknown
    \/ StatusFailure
    \/ \E kind \in {"completed", "failed", "timeout", "missing", "cancelled"} :
          ProviderTerminal(kind)
    \/ Drain
    \/ Recover
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ providerJob \in ProviderJobStates
    /\ executorState \in ExecutorStates
    /\ managerReady \in BOOLEAN
    /\ workerSlots \in 0..MAX_SLOTS
    /\ queued \in 0..MAX_TASKS
    /\ running \in 0..(MAX_TASKS + MAX_SLOTS)
    /\ lost \in 0..(MAX_TASKS + MAX_SLOTS)
    /\ submitRejected \in 0..MAX_FAILURES
    /\ statusFailures \in 0..MAX_FAILURES

AdmissionSafety ==
    managerReady => /\ providerJob \in {"running", "unknown"}
                     /\ executorState \in {"up", "draining"}

TerminalCleanup ==
    providerJob \in {"completed", "failed", "timeout", "missing", "cancelled"}
        => /\ ~managerReady
           /\ workerSlots = 0
           /\ queued = 0
           /\ running = 0
           /\ executorState = "failed"

ResourceSafety ==
    managerReady => workerSlots <= MAX_SLOTS

=============================================================================
