--------------------------- MODULE ParslRsyncPartialCleanupFutureMonitoring ---------------------------
EXTENDS Naturals

(***************************************************************************
 * RSync partial-destination cleanup composed with DataFuture/task failure.
 *
 * A non-zero rsync status can leave a destination path containing partial
 * bytes.  The Current wrapper reports an error but leaves that path visible
 * while dependents remain pending.  The Fixed branch removes the partial
 * publication and propagates failure through the Future and monitoring row.
 ***************************************************************************)

CONSTANT USE_FIXED

TransferStates == {"transferring", "failed"}
FutureStates == {"pending", "failed"}
TaskStates == {"blocked", "failed"}
MonitorStates == {"none", "failed"}

VARIABLES transfer, bytesPublished, dataFuture, task, monitor
vars == <<transfer, bytesPublished, dataFuture, task, monitor>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ transfer = "transferring"
    /\ bytesPublished = 1
    /\ dataFuture = "pending"
    /\ task = "blocked"
    /\ monitor = "none"

FailTransfer ==
    /\ transfer = "transferring"
    /\ transfer' = "failed"
    /\ bytesPublished' = IF USE_FIXED THEN 0 ELSE bytesPublished
    /\ dataFuture' = IF USE_FIXED THEN "failed" ELSE dataFuture
    /\ task' = IF USE_FIXED THEN "failed" ELSE task
    /\ monitor' = IF USE_FIXED THEN "failed" ELSE monitor

Next ==
    \/ FailTransfer
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ transfer \in TransferStates
    /\ bytesPublished \in 0..1
    /\ dataFuture \in FutureStates
    /\ task \in TaskStates
    /\ monitor \in MonitorStates

FailureCleanupSafety == transfer = "failed" => bytesPublished = 0

FailurePropagation ==
    task = "failed" =>
        /\ dataFuture = "failed"
        /\ monitor = "failed"

PendingReadinessSafety == dataFuture = "pending" => task = "blocked"

=============================================================================
