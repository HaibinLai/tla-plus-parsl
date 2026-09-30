--------------------------- MODULE ParslJoinCleanupLifecycle ---------------------------
EXTENDS Naturals

(***************************************************************************
 * join_app lifecycle across DataFlowKernel.cleanup.
 *
 * An outer join can be in `joining` after its body has returned an inner
 * Future.  The current cleanup path closes components and publishes workflow
 * completion without waiting for that logical task.  A later inner callback
 * can then mutate the task after cleanup returned.  The fixed branch waits
 * until the join is terminal before returning cleanup.
 ***************************************************************************)

CONSTANT USE_FIXED

OuterStates == {"new", "joining", "succeeded", "failed"}
CleanupStates == {"open", "started", "returned"}

VARIABLES outerState, innerState, cleanupState, workflowEnded
vars == <<outerState, innerState, cleanupState, workflowEnded>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ outerState = "new"
    /\ innerState = "pending"
    /\ cleanupState = "open"
    /\ workflowEnded = FALSE

StartJoin ==
    /\ outerState = "new"
    /\ outerState' = "joining"
    /\ UNCHANGED <<innerState, cleanupState, workflowEnded>>

Cleanup ==
    /\ cleanupState = "open"
    /\ IF USE_FIXED
          THEN outerState \in {"succeeded", "failed"}
          ELSE TRUE
    /\ cleanupState' = "started"
    /\ UNCHANGED <<outerState, innerState, workflowEnded>>

InnerComplete ==
    /\ outerState = "joining"
    /\ innerState = "pending"
    /\ innerState' = "done"
    /\ UNCHANGED <<outerState, cleanupState, workflowEnded>>

JoinFinalize ==
    /\ outerState = "joining"
    /\ innerState = "done"
    /\ outerState' = "succeeded"
    /\ UNCHANGED <<innerState, cleanupState, workflowEnded>>

PublishWorkflowEnd ==
    /\ cleanupState = "started"
    /\ cleanupState' = "returned"
    /\ workflowEnded' = TRUE
    /\ UNCHANGED <<outerState, innerState>>

Next ==
    \/ StartJoin
    \/ Cleanup
    \/ InnerComplete
    \/ JoinFinalize
    \/ PublishWorkflowEnd
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ outerState \in OuterStates
    /\ innerState \in {"pending", "done"}
    /\ cleanupState \in CleanupStates
    /\ workflowEnded \in BOOLEAN

WorkflowEndSafety ==
    workflowEnded => outerState # "joining"

JoinQuiescence ==
    cleanupState = "returned" => outerState # "joining"

TerminalCountSafety ==
    workflowEnded => outerState \in {"succeeded", "failed"}

=============================================================================
