--------------------------- MODULE ParslTaskStatusFutureOrdering ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Ordering between the logical DFK task status and its public AppFuture.
 *
 * DataFlowKernel._complete_task_result first publishes States.exec_done and
 * only then calls AppFuture.set_result.  The small lag is intentional: it
 * lets monitoring observe a terminal task before Future callbacks run.
 *************************************************************************** *)

CONSTANT ALLOW_STATUS_LAG

VARIABLES taskState, futureState
vars == <<taskState, futureState>>

Init ==
    /\ ALLOW_STATUS_LAG \in BOOLEAN
    /\ taskState = "running"
    /\ futureState = "pending"

PublishTaskStatus ==
    /\ taskState = "running"
    /\ taskState' = "exec_done"
    /\ UNCHANGED futureState

PublishFutureResult ==
    /\ taskState = "exec_done"
    /\ futureState = "pending"
    /\ futureState' = "done"
    /\ UNCHANGED taskState

Next ==
    \/ PublishTaskStatus
    \/ PublishFutureResult
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ ALLOW_STATUS_LAG \in BOOLEAN
    /\ taskState \in {"running", "exec_done"}
    /\ futureState \in {"pending", "done"}

FutureCompletionSafety ==
    futureState = "done" => taskState = "exec_done"

StatusLagPolicy ==
    taskState = "exec_done" /\ futureState = "pending" => ALLOW_STATUS_LAG

=============================================================================
