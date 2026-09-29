--------------------------- MODULE ParslProvisioningAdmissionMonitoring ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Provider provisioning, executor admission, and monitoring.
 *
 * A queued task needs an active provider block before the executor can admit
 * it.  A failed scale-out or a block loss must be visible to monitoring and
 * must not leave a task running without capacity.  The current branch drops
 * the failed-block monitoring update; the fixed branch reports it.
 ***************************************************************************)

CONSTANTS MAX_BLOCKS, USE_FIXED

ProviderStates == {"down", "pending", "active", "failed"}
TaskStates == {"pending", "running", "retry_wait", "done"}
MonitorStates == {"none", "running", "failed", "succeeded"}

VARIABLES desiredBlocks, provider, task, monitor
vars == <<desiredBlocks, provider, task, monitor>>

Init ==
    /\ MAX_BLOCKS > 0
    /\ USE_FIXED \in BOOLEAN
    /\ desiredBlocks = 0
    /\ provider = "down"
    /\ task = "pending"
    /\ monitor = "none"

RequestBlock ==
    /\ desiredBlocks < MAX_BLOCKS
    /\ desiredBlocks' = desiredBlocks + 1
    /\ provider' = "pending"
    /\ UNCHANGED <<task, monitor>>

AllocationSucceeds ==
    /\ provider = "pending"
    /\ provider' = "active"
    /\ UNCHANGED <<desiredBlocks, task, monitor>>

AllocationFails ==
    /\ provider = "pending"
    /\ provider' = "failed"
    /\ monitor' = IF USE_FIXED THEN "failed" ELSE monitor
    /\ UNCHANGED <<desiredBlocks, task>>

SubmitTask ==
    /\ task = "pending"
    /\ provider = "active"
    /\ task' = "running"
    /\ monitor' = "running"
    /\ UNCHANGED <<desiredBlocks, provider>>

BlockFails ==
    /\ provider = "active"
    /\ provider' = "failed"
    /\ task' = IF task = "running" THEN "retry_wait" ELSE task
    /\ monitor' = IF USE_FIXED THEN "failed" ELSE monitor
    /\ UNCHANGED desiredBlocks

RetryProvisioning ==
    /\ provider = "failed"
    /\ task = "retry_wait"
    /\ provider' = "pending"
    /\ task' = "pending"
    /\ monitor' = "failed"
    /\ UNCHANGED desiredBlocks

CompleteTask ==
    /\ task = "running"
    /\ provider = "active"
    /\ task' = "done"
    /\ monitor' = "succeeded"
    /\ UNCHANGED <<desiredBlocks, provider>>

Next ==
    \/ RequestBlock
    \/ AllocationSucceeds
    \/ AllocationFails
    \/ SubmitTask
    \/ BlockFails
    \/ RetryProvisioning
    \/ CompleteTask
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ desiredBlocks \in 0..MAX_BLOCKS
    /\ provider \in ProviderStates
    /\ task \in TaskStates
    /\ monitor \in MonitorStates

AdmissionSafety ==
    task = "running" => provider = "active"

FailureVisibility ==
    provider = "failed" => monitor = "failed"

TerminalMonitoring ==
    monitor = "succeeded" => task = "done" /\ provider = "active"

=============================================================================
