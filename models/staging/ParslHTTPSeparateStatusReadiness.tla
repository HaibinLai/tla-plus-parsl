--------------------------- MODULE ParslHTTPSeparateStatusReadiness ---------------------------
EXTENDS Naturals

(***************************************************************************
 * HTTP separate-task stage-in, DataFuture publication, and consumer admission.
 *
 * The separate-task helper currently completes normally after streaming an
 * HTTP response, even when the response is non-2xx.  DataFlowKernel therefore
 * treats the output DataFuture as ready and can admit a dependent task with
 * an error page.  USE_FIXED models status validation before publication and
 * coordinated failure propagation.
 ***************************************************************************)

CONSTANTS STATUS_CODE, USE_FIXED

TransferStates == {"requested", "received", "published", "rejected"}
FutureStates == {"pending", "ready", "failed"}
TaskStates == {"blocked", "running", "failed"}
MonitorStates == {"none", "ready", "failed"}

VARIABLES transfer, dataFuture, task, monitor, bytesVisible
vars == <<transfer, dataFuture, task, monitor, bytesVisible>>

Init ==
    /\ STATUS_CODE \in 100..599
    /\ USE_FIXED \in BOOLEAN
    /\ transfer = "requested"
    /\ dataFuture = "pending"
    /\ task = "blocked"
    /\ monitor = "none"
    /\ bytesVisible = FALSE

Receive ==
    /\ transfer = "requested"
    /\ transfer' = "received"
    /\ UNCHANGED <<dataFuture, task, monitor, bytesVisible>>

PublishSuccess ==
    /\ transfer = "received"
    /\ STATUS_CODE \in 200..299
    /\ transfer' = "published"
    /\ dataFuture' = "ready"
    /\ task' = "running"
    /\ monitor' = "ready"
    /\ bytesVisible' = TRUE

PublishCurrentError ==
    /\ transfer = "received"
    /\ STATUS_CODE \notin 200..299
    /\ ~USE_FIXED
    /\ transfer' = "published"
    /\ dataFuture' = "ready"
    /\ task' = "running"
    /\ monitor' = "ready"
    /\ bytesVisible' = TRUE

RejectError ==
    /\ transfer = "received"
    /\ STATUS_CODE \notin 200..299
    /\ USE_FIXED
    /\ transfer' = "rejected"
    /\ dataFuture' = "failed"
    /\ task' = "failed"
    /\ monitor' = "failed"
    /\ UNCHANGED bytesVisible

Next ==
    \/ Receive
    \/ PublishSuccess
    \/ PublishCurrentError
    \/ RejectError
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ STATUS_CODE \in 100..599
    /\ USE_FIXED \in BOOLEAN
    /\ transfer \in TransferStates
    /\ dataFuture \in FutureStates
    /\ task \in TaskStates
    /\ monitor \in MonitorStates
    /\ bytesVisible \in BOOLEAN

InvalidReadySafety ==
    dataFuture = "ready" => STATUS_CODE \in 200..299

ConsumerAdmissionSafety ==
    task = "running" => dataFuture = "ready" /\ bytesVisible

FailureConsistency ==
    task = "failed" => dataFuture = "failed" /\ monitor = "failed"

================================================================================
