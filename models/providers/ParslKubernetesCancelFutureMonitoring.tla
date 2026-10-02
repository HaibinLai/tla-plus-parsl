--------------------------- MODULE ParslKubernetesCancelFutureMonitoring ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Kubernetes cancellation propagation.
 *
 * The provider returns a deletion response, while executor and monitoring
 * layers publish cancellation for the logical task.  The Current branch
 * ignores a failed Kubernetes delete response and propagates cancellation
 * anyway.  USE_FIXED requires confirmed remote deletion before publishing a
 * terminal Future/monitoring state.  This refines BUG-189 across layers.
 ***************************************************************************)

CONSTANT USE_FIXED

DeleteStates == {"unknown", "success", "failure"}
LocalStates == {"running", "cancelled"}
FutureStates == {"pending", "cancelled"}
MonitorStates == {"none", "cancelled"}

VARIABLES deleteResponse, local, future, monitor
vars == <<deleteResponse, local, future, monitor>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ deleteResponse = "unknown"
    /\ local = "running"
    /\ future = "pending"
    /\ monitor = "none"

DeleteResult(kind) ==
    /\ kind \in {"success", "failure"}
    /\ deleteResponse = "unknown"
    /\ deleteResponse' = kind
    /\ UNCHANGED <<local, future, monitor>>

PublishCancel ==
    /\ deleteResponse \in {"success", "failure"}
    /\ IF USE_FIXED THEN deleteResponse = "success" ELSE TRUE
    /\ local' = "cancelled"
    /\ future' = "cancelled"
    /\ monitor' = "cancelled"
    /\ UNCHANGED deleteResponse

NoOp == UNCHANGED vars

Next ==
    \/ \E kind \in {"success", "failure"} : DeleteResult(kind)
    \/ PublishCancel
    \/ NoOp

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ deleteResponse \in DeleteStates
    /\ local \in LocalStates
    /\ future \in FutureStates
    /\ monitor \in MonitorStates

CancellationRequiresRemoteSuccess ==
    future = "cancelled" => deleteResponse = "success"

MonitorMatchesFuture ==
    monitor = "cancelled" => future = "cancelled"

LocalTerminalMatchesFuture ==
    local = "cancelled" => future = "cancelled"

=============================================================================
