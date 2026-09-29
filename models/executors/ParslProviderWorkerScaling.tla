--------------------------- MODULE ParslProviderWorkerScaling ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Provider block scaling and executor worker admission.
 *
 * A provider block being active is not itself an executable worker.  The
 * executor admits work only after a manager registers worker slots.  Scale-in
 * removes only idle registered capacity in this small model; provider failure
 * revokes all admission and leaves queued work for recovery.
 ***************************************************************************)

CONSTANTS MAX_BLOCKS, WORKERS_PER_BLOCK, MAX_TASKS

ProviderStates == {"down", "pending", "active", "failed"}
TaskStates == {"blocked", "queued", "running", "done"}

VARIABLES requestedBlocks, activeBlocks, registeredWorkers,
          freeWorkers, task, provider
vars == <<requestedBlocks, activeBlocks, registeredWorkers,
           freeWorkers, task, provider>>

Init ==
    /\ MAX_BLOCKS > 0
    /\ WORKERS_PER_BLOCK > 0
    /\ MAX_TASKS > 0
    /\ requestedBlocks = 0
    /\ activeBlocks = 0
    /\ registeredWorkers = 0
    /\ freeWorkers = 0
    /\ task = "blocked"
    /\ provider = "down"

ScaleOut ==
    /\ requestedBlocks < MAX_BLOCKS
    /\ requestedBlocks' = requestedBlocks + 1
    /\ provider' = IF provider = "down" THEN "pending" ELSE provider
    /\ UNCHANGED <<activeBlocks, registeredWorkers, freeWorkers, task>>

ProvisionBlock ==
    /\ provider = "pending"
    /\ activeBlocks < requestedBlocks
    /\ activeBlocks' = activeBlocks + 1
    /\ provider' = "active"
    /\ UNCHANGED <<requestedBlocks, registeredWorkers, freeWorkers, task>>

RegisterManager ==
    /\ provider = "active"
    /\ registeredWorkers < activeBlocks * WORKERS_PER_BLOCK
    /\ registeredWorkers' = registeredWorkers + WORKERS_PER_BLOCK
    /\ freeWorkers' = freeWorkers + WORKERS_PER_BLOCK
    /\ UNCHANGED <<requestedBlocks, activeBlocks, task, provider>>

SubmitTask ==
    /\ task = "blocked"
    /\ freeWorkers > 0
    /\ provider = "active"
    /\ freeWorkers' = freeWorkers - 1
    /\ task' = "queued"
    /\ UNCHANGED <<requestedBlocks, activeBlocks, registeredWorkers, provider>>

StartTask ==
    /\ task = "queued"
    /\ task' = "running"
    /\ UNCHANGED <<requestedBlocks, activeBlocks, registeredWorkers,
                    freeWorkers, provider>>

CompleteTask ==
    /\ task = "running"
    /\ task' = "done"
    /\ freeWorkers' = freeWorkers + 1
    /\ UNCHANGED <<requestedBlocks, activeBlocks, registeredWorkers, provider>>

ScaleInIdle ==
    /\ activeBlocks > 0
    /\ freeWorkers >= WORKERS_PER_BLOCK
    /\ activeBlocks' = activeBlocks - 1
    /\ requestedBlocks' = requestedBlocks - 1
    /\ registeredWorkers' = registeredWorkers - WORKERS_PER_BLOCK
    /\ freeWorkers' = freeWorkers - WORKERS_PER_BLOCK
    /\ provider' = IF activeBlocks = 1 THEN "down" ELSE provider
    /\ UNCHANGED task

ProviderFailure ==
    /\ provider \in {"pending", "active"}
    /\ provider' = "failed"
    /\ activeBlocks' = 0
    /\ registeredWorkers' = 0
    /\ freeWorkers' = 0
    /\ task' = IF task \in {"queued", "running"} THEN "blocked" ELSE task
    /\ UNCHANGED requestedBlocks

Next ==
    \/ ScaleOut
    \/ ProvisionBlock
    \/ RegisterManager
    \/ SubmitTask
    \/ StartTask
    \/ CompleteTask
    \/ ScaleInIdle
    \/ ProviderFailure
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ requestedBlocks \in 0..MAX_BLOCKS
    /\ activeBlocks \in 0..MAX_BLOCKS
    /\ registeredWorkers \in 0..(MAX_BLOCKS * WORKERS_PER_BLOCK)
    /\ freeWorkers \in 0..(MAX_BLOCKS * WORKERS_PER_BLOCK)
    /\ task \in {"blocked", "queued", "running", "done"}
    /\ provider \in ProviderStates

AdmissionSafety ==
    task \in {"queued", "running"} =>
        registeredWorkers > 0 /\ provider = "active"

CapacitySafety ==
    /\ freeWorkers <= registeredWorkers
    /\ registeredWorkers <= activeBlocks * WORKERS_PER_BLOCK

ScaleInSafety ==
    task = "running" => activeBlocks > 0

FailureRevokesAdmission ==
    provider = "failed" =>
        /\ activeBlocks = 0
        /\ registeredWorkers = 0
        /\ freeWorkers = 0

=============================================================================
