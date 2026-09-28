--------------------------- MODULE ParslExecutorProviderLifecycle ---------------------------
EXTENDS Naturals, FiniteSets

(***************************************************************************
 * A compact provider/executor lifecycle model.
 *
 * A provider block becomes capacity only after allocation and manager
 * registration.  Executor drain rejects new work but allows admitted work to
 * finish.  Provider terminal status revokes admission and accounts for
 * queued/running work.  The current branch can scale below MIN_BLOCKS; the
 * fixed branch enforces the provider floor.
 ***************************************************************************)

CONSTANTS MAX_BLOCKS, MIN_BLOCKS, SLOTS_PER_BLOCK, MAX_TASKS, USE_FIXED

ProviderStates == {"down", "requested", "active", "failed"}
ExecutorStates == {"down", "up", "draining", "failed"}

VARIABLES providerState, executorState, pendingBlocks, activeBlocks,
          managerReady, freeSlots, queued, running, completed, lost

vars == <<providerState, executorState, pendingBlocks, activeBlocks,
           managerReady, freeSlots, queued, running, completed, lost>>

Init ==
    /\ MAX_BLOCKS > 0
    /\ MIN_BLOCKS <= MAX_BLOCKS
    /\ SLOTS_PER_BLOCK > 0
    /\ MAX_TASKS > 0
    /\ providerState = "down"
    /\ executorState = "down"
    /\ pendingBlocks = 0
    /\ activeBlocks = 0
    /\ managerReady = FALSE
    /\ freeSlots = 0
    /\ queued = 0
    /\ running = 0
    /\ completed = 0
    /\ lost = 0

StartExecutor ==
    /\ executorState = "down"
    /\ executorState' = "up"
    /\ UNCHANGED <<providerState, pendingBlocks, activeBlocks, managerReady,
                    freeSlots, queued, running, completed, lost>>

RequestBlock ==
    /\ executorState = "up"
    /\ providerState = "down"
    /\ activeBlocks + pendingBlocks < MAX_BLOCKS
    /\ providerState' = "requested"
    /\ pendingBlocks' = pendingBlocks + 1
    /\ UNCHANGED <<executorState, activeBlocks, managerReady, freeSlots,
                    queued, running, completed, lost>>

AllocationSucceeds ==
    /\ providerState = "requested"
    /\ pendingBlocks > 0
    /\ providerState' = "active"
    /\ pendingBlocks' = pendingBlocks - 1
    /\ activeBlocks' = activeBlocks + 1
    /\ UNCHANGED <<executorState, managerReady, freeSlots, queued,
                    running, completed, lost>>

RegisterManager ==
    /\ executorState = "up"
    /\ providerState = "active"
    /\ ~managerReady
    /\ managerReady' = TRUE
    /\ freeSlots' = activeBlocks * SLOTS_PER_BLOCK
    /\ UNCHANGED <<providerState, executorState, pendingBlocks, activeBlocks,
                    queued, running, completed, lost>>

SubmitTask ==
    /\ executorState = "up"
    /\ providerState = "active"
    /\ managerReady
    /\ freeSlots > 0
    /\ queued + running + completed + lost < MAX_TASKS
    /\ queued' = queued + 1
    /\ freeSlots' = freeSlots - 1
    /\ UNCHANGED <<providerState, executorState, pendingBlocks, activeBlocks,
                    managerReady, running, completed, lost>>

StartQueued ==
    /\ queued > 0
    /\ executorState \in {"up", "draining"}
    /\ queued' = queued - 1
    /\ running' = running + 1
    /\ UNCHANGED <<providerState, executorState, pendingBlocks, activeBlocks,
                    managerReady, freeSlots, completed, lost>>

CompleteTask ==
    /\ running > 0
    /\ running' = running - 1
    /\ completed' = completed + 1
    /\ freeSlots' = freeSlots + 1
    /\ UNCHANGED <<providerState, executorState, pendingBlocks, activeBlocks,
                    managerReady, queued, lost>>

DrainExecutor ==
    /\ executorState = "up"
    /\ executorState' = "draining"
    /\ UNCHANGED <<providerState, pendingBlocks, activeBlocks, managerReady,
                    freeSlots, queued, running, completed, lost>>

RecoverExecutor ==
    /\ executorState = "draining"
    /\ providerState = "active"
    /\ executorState' = "up"
    /\ UNCHANGED <<providerState, pendingBlocks, activeBlocks, managerReady,
                    freeSlots, queued, running, completed, lost>>

ScaleIn ==
    /\ providerState = "active"
    /\ managerReady
    /\ queued = 0
    /\ running = 0
    /\ IF USE_FIXED THEN activeBlocks > MIN_BLOCKS ELSE activeBlocks > 0
    /\ activeBlocks' = activeBlocks - 1
    /\ freeSlots' = (activeBlocks - 1) * SLOTS_PER_BLOCK
    /\ providerState' = "active"
    /\ managerReady' = managerReady
    /\ UNCHANGED <<executorState, pendingBlocks, queued, running,
                    completed, lost>>

ProviderTerminal ==
    /\ providerState \in {"requested", "active"}
    /\ providerState' = "failed"
    /\ executorState' = "failed"
    /\ pendingBlocks' = 0
    /\ activeBlocks' = 0
    /\ managerReady' = FALSE
    /\ freeSlots' = 0
    /\ lost' = lost + queued + running
    /\ queued' = 0
    /\ running' = 0
    /\ UNCHANGED completed

Next ==
    \/ StartExecutor
    \/ RequestBlock
    \/ AllocationSucceeds
    \/ RegisterManager
    \/ SubmitTask
    \/ StartQueued
    \/ CompleteTask
    \/ DrainExecutor
    \/ RecoverExecutor
    \/ ScaleIn
    \/ ProviderTerminal
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ providerState \in ProviderStates
    /\ executorState \in ExecutorStates
    /\ pendingBlocks \in 0..MAX_BLOCKS
    /\ activeBlocks \in 0..MAX_BLOCKS
    /\ managerReady \in BOOLEAN
    /\ freeSlots \in 0..(MAX_BLOCKS * SLOTS_PER_BLOCK)
    /\ queued \in 0..MAX_TASKS
    /\ running \in 0..MAX_TASKS
    /\ completed \in 0..MAX_TASKS
    /\ lost \in 0..MAX_TASKS

MinBlockSafety ==
    providerState = "active" => activeBlocks >= MIN_BLOCKS

AdmissionSafety ==
    managerReady => providerState = "active" /\ executorState \in {"up", "draining"}

CapacitySafety ==
    freeSlots <= activeBlocks * SLOTS_PER_BLOCK

TerminalCleanup ==
    providerState = "failed" =>
        /\ executorState = "failed"
        /\ ~managerReady
        /\ activeBlocks = 0
        /\ pendingBlocks = 0
        /\ freeSlots = 0
        /\ queued = 0
        /\ running = 0

=============================================================================
