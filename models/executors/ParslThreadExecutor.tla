--------------------------- MODULE ParslThreadExecutor ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Focused model of the provider-free ThreadPoolExecutor.
 * Resource specifications are rejected before a Future is created.  A
 * shutdown with wait=True waits for accepted work; wait=False marks the
 * executor stopped while accepted work may still complete in the background.
 ***************************************************************************)

CONSTANTS BLOCK, RESOURCE_VALID
MAX_REJECTIONS == 2

ExecutorStates == {"down", "running", "shutting", "stopped"}
TaskStates == {"none", "running", "done"}
VARIABLES executorState, taskState, rejected
vars == <<executorState, taskState, rejected>>

Init ==
    /\ BLOCK \in BOOLEAN
    /\ RESOURCE_VALID \in BOOLEAN
    /\ executorState = "down"
    /\ taskState = "none"
    /\ rejected = 0

Start ==
    /\ executorState = "down"
    /\ executorState' = "running"
    /\ UNCHANGED <<taskState, rejected>>

Submit ==
    /\ executorState = "running"
    /\ RESOURCE_VALID
    /\ taskState = "none"
    /\ taskState' = "running"
    /\ UNCHANGED <<executorState, rejected>>

RejectResource ==
    /\ executorState = "running"
    /\ ~RESOURCE_VALID
    /\ taskState = "none"
    /\ rejected < MAX_REJECTIONS
    /\ rejected' = rejected + 1
    /\ UNCHANGED <<executorState, taskState>>

BeginShutdown ==
    /\ executorState = "running"
    /\ executorState' = "shutting"
    /\ UNCHANGED <<taskState, rejected>>

CompleteTask ==
    /\ taskState = "running"
    /\ taskState' = "done"
    /\ UNCHANGED <<executorState, rejected>>

FinishShutdown ==
    /\ executorState = "shutting"
    /\ IF BLOCK THEN taskState \in {"none", "done"} ELSE TRUE
    /\ executorState' = "stopped"
    /\ UNCHANGED <<taskState, rejected>>

RejectAfterShutdown ==
    /\ executorState \in {"shutting", "stopped"}
    /\ rejected < MAX_REJECTIONS
    /\ rejected' = rejected + 1
    /\ UNCHANGED <<executorState, taskState>>

Next ==
    \/ Start
    \/ Submit
    \/ RejectResource
    \/ BeginShutdown
    \/ CompleteTask
    \/ FinishShutdown
    \/ RejectAfterShutdown
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ executorState \in ExecutorStates
    /\ taskState \in TaskStates
    /\ rejected \in 0..MAX_REJECTIONS

ResourceSafety ==
    ~RESOURCE_VALID => taskState = "none"

BlockingShutdownSafety ==
    BLOCK /\ executorState = "stopped" => taskState \in {"none", "done"}

=============================================================================
