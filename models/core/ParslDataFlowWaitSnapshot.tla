--------------------------- MODULE ParslDataFlowWaitSnapshot ---------------------------
EXTENDS Naturals

(***************************************************************************
 * DataFlowKernel.wait_for_current_tasks snapshots self.tasks before waiting.
 * A task inserted after that snapshot can remain pending when the method
 * returns.  USE_FIXED models a second drain/check before returning.
 ***************************************************************************)

CONSTANT USE_FIXED
States == {"open", "snapshot", "waiting", "returned"}

VARIABLES state, snapshotTaken, lateTaskPending, returned
vars == <<state, snapshotTaken, lateTaskPending, returned>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ state = "open"
    /\ snapshotTaken = FALSE
    /\ lateTaskPending = FALSE
    /\ returned = FALSE

TakeSnapshot ==
    /\ state = "open"
    /\ state' = "snapshot"
    /\ snapshotTaken' = TRUE
    /\ UNCHANGED <<lateTaskPending, returned>>

AddLateTask ==
    /\ snapshotTaken
    /\ state \in {"snapshot", "waiting"}
    /\ lateTaskPending' = TRUE
    /\ state' = "waiting"
    /\ UNCHANGED <<snapshotTaken, returned>>

CompleteSnapshotTasks ==
    /\ state \in {"snapshot", "waiting"}
    /\ state' = "waiting"
    /\ UNCHANGED <<snapshotTaken, lateTaskPending, returned>>

DrainLateTask ==
    /\ USE_FIXED
    /\ state = "waiting"
    /\ lateTaskPending
    /\ lateTaskPending' = FALSE
    /\ UNCHANGED <<state, snapshotTaken, returned>>

Return ==
    /\ state = "waiting"
    /\ ~USE_FIXED \/ ~lateTaskPending
    /\ state' = "returned"
    /\ returned' = TRUE
    /\ UNCHANGED <<snapshotTaken, lateTaskPending>>

Next ==
    \/ TakeSnapshot
    \/ AddLateTask
    \/ CompleteSnapshotTasks
    \/ DrainLateTask
    \/ Return
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ state \in States
    /\ snapshotTaken \in BOOLEAN
    /\ lateTaskPending \in BOOLEAN
    /\ returned \in BOOLEAN

SnapshotSafety == returned => snapshotTaken

NoPendingTaskAtReturn == returned => ~lateTaskPending

=============================================================================
