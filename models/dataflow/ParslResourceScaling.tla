--------------------------- MODULE ParslResourceScaling ---------------------------
EXTENDS Naturals, FiniteSets

(***************************************************************************
 * Resource-aware scaling boundary.
 *
 * The strategy sees outstanding work and block capacity, while the executor
 * admission path sees per-task core demand.  A pending allocation can fail
 * without removing existing blocks; a later strategy step may request it
 * again.  This is a small resource-aware refinement of Strategy's slot rule.
 ***************************************************************************)

CONSTANTS TASKS, MAX_BLOCKS, MIN_BLOCKS, CORES_PER_BLOCK,
          HIGH_CORES, LOW_CORES, MAX_FAILURES

TaskStates == {"absent", "pending", "running", "done"}

VARIABLES taskState, activeBlocks, pendingBlocks, usedCores,
          scaleFailures, lost
vars == <<taskState, activeBlocks, pendingBlocks, usedCores,
          scaleFailures, lost>>

TaskCores(t) == IF t = "T1" THEN HIGH_CORES ELSE LOW_CORES
Demand ==
    (IF taskState["T1"] \in {"pending", "running"}
     THEN HIGH_CORES ELSE 0)
    + (IF taskState["T2"] \in {"pending", "running"}
       THEN LOW_CORES ELSE 0)

Init ==
    /\ TASKS = {"T1", "T2"}
    /\ MAX_BLOCKS > 0
    /\ MIN_BLOCKS <= MAX_BLOCKS
    /\ CORES_PER_BLOCK > 0
    /\ HIGH_CORES > 0
    /\ LOW_CORES > 0
    /\ MAX_FAILURES > 0
    /\ taskState = [t \in TASKS |-> "absent"]
    /\ activeBlocks = 0
    /\ pendingBlocks = 0
    /\ usedCores = 0
    /\ scaleFailures = 0
    /\ lost = 0

Submit(t) ==
    /\ t \in TASKS
    /\ taskState[t] = "absent"
    /\ taskState' = [taskState EXCEPT ![t] = "pending"]
    /\ UNCHANGED <<activeBlocks, pendingBlocks, usedCores,
                    scaleFailures, lost>>

ScaleOut ==
    /\ activeBlocks + pendingBlocks < MAX_BLOCKS
    /\ Demand > activeBlocks * CORES_PER_BLOCK
    /\ pendingBlocks' = pendingBlocks + 1
    /\ UNCHANGED <<taskState, activeBlocks, usedCores,
                    scaleFailures, lost>>

AllocationSucceeds ==
    /\ pendingBlocks > 0
    /\ pendingBlocks' = pendingBlocks - 1
    /\ activeBlocks' = activeBlocks + 1
    /\ UNCHANGED <<taskState, usedCores, scaleFailures, lost>>

AllocationFails ==
    /\ pendingBlocks > 0
    /\ scaleFailures < MAX_FAILURES
    /\ pendingBlocks' = pendingBlocks - 1
    /\ scaleFailures' = scaleFailures + 1
    /\ UNCHANGED <<taskState, activeBlocks, usedCores, lost>>

Dispatch(t) ==
    /\ t \in TASKS
    /\ taskState[t] = "pending"
    /\ usedCores + TaskCores(t) <= activeBlocks * CORES_PER_BLOCK
    /\ taskState' = [taskState EXCEPT ![t] = "running"]
    /\ usedCores' = usedCores + TaskCores(t)
    /\ UNCHANGED <<activeBlocks, pendingBlocks, scaleFailures, lost>>

Complete(t) ==
    /\ t \in TASKS
    /\ taskState[t] = "running"
    /\ taskState' = [taskState EXCEPT ![t] = "done"]
    /\ usedCores' = usedCores - TaskCores(t)
    /\ UNCHANGED <<activeBlocks, pendingBlocks, scaleFailures, lost>>

ScaleIn ==
    /\ activeBlocks > MIN_BLOCKS
    /\ activeBlocks > 0
    /\ usedCores = 0
    /\ pendingBlocks = 0
    /\ activeBlocks' = activeBlocks - 1
    /\ UNCHANGED <<taskState, pendingBlocks, usedCores,
                    scaleFailures, lost>>

Next ==
    \/ \E t \in TASKS : Submit(t) \/ Dispatch(t) \/ Complete(t)
    \/ ScaleOut
    \/ AllocationSucceeds
    \/ AllocationFails
    \/ ScaleIn
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ taskState \in [TASKS -> TaskStates]
    /\ activeBlocks \in 0..MAX_BLOCKS
    /\ pendingBlocks \in 0..MAX_BLOCKS
    /\ activeBlocks + pendingBlocks <= MAX_BLOCKS
    /\ usedCores \in 0..(MAX_BLOCKS * CORES_PER_BLOCK)
    /\ scaleFailures \in 0..MAX_FAILURES
    /\ lost \in 0..Cardinality(TASKS)

CapacitySafety ==
    usedCores <= activeBlocks * CORES_PER_BLOCK

DemandSafety ==
    \A t \in TASKS : taskState[t] = "running" => usedCores >= TaskCores(t)

ScaleFailureSafety ==
    scaleFailures > 0 => activeBlocks >= MIN_BLOCKS

AdmissionSafety ==
    \A t \in TASKS : taskState[t] = "running"
        => usedCores <= activeBlocks * CORES_PER_BLOCK

=============================================================================
