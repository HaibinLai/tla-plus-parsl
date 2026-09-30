------------------------ MODULE ParslProviderTaskScaleRetry ------------------------
EXTENDS Naturals

(***************************************************************************
 * Provider capacity, task admission, scale-in, and retry.
 *
 * A provider block is requested before an executor admits a task.  Scaling
 * in the last active block while a task is running must withdraw that
 * physical attempt and move the logical task to retry_wait.  The Current
 * branch leaves the task running without capacity; the Fixed branch preserves
 * admission and monitoring invariants.
 *************************************************************************** *)

CONSTANT USE_FIXED, MAX_BLOCKS
ProviderStates == {"down", "pending", "active", "failed"}
TaskStates == {"pending", "running", "retry_wait", "done"}
MonitorStates == {"none", "running", "failed", "succeeded"}

VARIABLES blocks, provider, task, attempt, monitor
vars == <<blocks, provider, task, attempt, monitor>>

Init ==
    /\ MAX_BLOCKS > 0
    /\ blocks = 0
    /\ provider = "down"
    /\ task = "pending"
    /\ attempt = 0
    /\ monitor = "none"

RequestBlock ==
    /\ blocks < MAX_BLOCKS
    /\ provider \in {"down", "failed"}
    /\ blocks' = blocks + 1
    /\ provider' = "pending"
    /\ UNCHANGED <<task, attempt, monitor>>

ProvisionSucceeds ==
    /\ provider = "pending"
    /\ provider' = "active"
    /\ UNCHANGED <<blocks, task, attempt, monitor>>

ProvisionFails ==
    /\ provider = "pending"
    /\ provider' = "failed"
    /\ monitor' = "failed"
    /\ UNCHANGED <<blocks, task, attempt>>

SubmitTask ==
    /\ task = "pending"
    /\ provider = "active"
    /\ blocks > 0
    /\ task' = "running"
    /\ monitor' = "running"
    /\ UNCHANGED <<blocks, provider, attempt>>

ScaleIn ==
    /\ provider = "active"
    /\ blocks > 0
    /\ task = "running"
    /\ blocks' = blocks - 1
    /\ provider' = IF blocks' = 0 THEN "down" ELSE "active"
    /\ IF USE_FIXED
          THEN /\ task' = "retry_wait"
               /\ monitor' = "failed"
          ELSE /\ UNCHANGED <<task, monitor>>
    /\ UNCHANGED attempt

RetryTask ==
    /\ task = "retry_wait"
    /\ attempt < 1
    /\ task' = "pending"
    /\ attempt' = attempt + 1
    /\ UNCHANGED <<blocks, provider, monitor>>

CompleteTask ==
    /\ task = "running"
    /\ provider = "active"
    /\ blocks > 0
    /\ task' = "done"
    /\ monitor' = "succeeded"
    /\ UNCHANGED <<blocks, provider, attempt>>

Next ==
    \/ RequestBlock \/ ProvisionSucceeds \/ ProvisionFails
    \/ SubmitTask \/ ScaleIn \/ RetryTask \/ CompleteTask
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ blocks \in 0..MAX_BLOCKS
    /\ provider \in ProviderStates
    /\ task \in TaskStates
    /\ attempt \in 0..1
    /\ monitor \in MonitorStates

AdmissionSafety == task = "running" => provider = "active" /\ blocks > 0
FailureVisibility == provider = "failed" => monitor = "failed"
RetryBound == attempt <= 1
TerminalMonitoring == monitor = "succeeded" => task = "done"

=============================================================================
