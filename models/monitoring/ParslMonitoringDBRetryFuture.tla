--------------------------- MODULE ParslMonitoringDBRetryFuture ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Monitoring DB retry composed with task/Future terminality.
 *
 * A task can complete successfully before its SQLite status write.  A
 * persistent OperationalError must not make the monitoring thread retry
 * forever or roll back the already-resolved Future.  The fixed branch uses
 * a bounded budget and records an aborted monitoring write at the bound.
 ***************************************************************************)

CONSTANT USE_FIXED
MAX_ATTEMPTS == 2

DbStates == {"queued", "writing", "retrying", "stored", "aborted"}
TaskStates == {"pending", "succeeded"}
FutureStates == {"pending", "succeeded"}
MonitorStates == {"none", "pending", "stored", "aborted"}

VARIABLES db, attempts, task, future, monitor
vars == <<db, attempts, task, future, monitor>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ db = "queued"
    /\ attempts = 0
    /\ task = "pending"
    /\ future = "pending"
    /\ monitor = "none"

CompleteTask ==
    /\ task = "pending"
    /\ task' = "succeeded"
    /\ future' = "succeeded"
    /\ UNCHANGED <<db, attempts, monitor>>

BeginInsert ==
    /\ db = "queued"
    /\ db' = "writing"
    /\ monitor' = "pending"
    /\ UNCHANGED <<attempts, task, future>>

OperationalFailure ==
    /\ db = "writing"
    /\ db' = IF USE_FIXED /\ attempts + 1 >= MAX_ATTEMPTS
             THEN "aborted" ELSE "retrying"
    /\ monitor' = IF USE_FIXED /\ attempts + 1 >= MAX_ATTEMPTS
                  THEN "aborted" ELSE "pending"
    /\ attempts' = IF USE_FIXED /\ attempts + 1 >= MAX_ATTEMPTS
                   THEN MAX_ATTEMPTS ELSE attempts + 1
    /\ UNCHANGED <<task, future>>

RetryWait ==
    /\ db = "retrying"
    /\ db' = "writing"
    /\ UNCHANGED <<attempts, task, future, monitor>>

InsertSuccess ==
    /\ db = "writing"
    /\ future = "succeeded"
    /\ db' = "stored"
    /\ monitor' = "stored"
    /\ UNCHANGED <<attempts, task, future>>

Next ==
    \/ CompleteTask
    \/ BeginInsert
    \/ OperationalFailure
    \/ RetryWait
    \/ InsertSuccess
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ db \in DbStates
    /\ attempts \in 0..MAX_ATTEMPTS
    /\ task \in TaskStates
    /\ future \in FutureStates
    /\ monitor \in MonitorStates

FutureConsistency == future = "succeeded" => task = "succeeded"

MonitoringDoesNotRollbackFuture ==
    monitor = "stored" => future = "succeeded"

BoundedMonitoringRetry ==
    USE_FIXED => attempts < MAX_ATTEMPTS \/ db \in {"stored", "aborted"}

NoPersistentRetryAtBound ==
    db = "retrying" => attempts < MAX_ATTEMPTS

=============================================================================
