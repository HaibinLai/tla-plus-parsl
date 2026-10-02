--------------------------- MODULE ParslBlockProviderBadStateMonitoring ---------------------------
EXTENDS Naturals

(***************************************************************************
 * BlockProviderExecutor bad-state fan-out with Future and monitoring state.
 *
 * set_bad_state_and_fail_all completes Futures while iterating the live task
 * dictionary.  A callback can remove an entry, aborting the sweep and leaving
 * independent logical tasks and monitoring rows pending.  USE_FIXED models a
 * snapshot-based sweep that terminalizes every outstanding task.
 ***************************************************************************)

CONSTANT USE_FIXED
TASKS == 2

VARIABLES state, remaining, failed, monitored
vars == <<state, remaining, failed, monitored>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ state = "failing"
    /\ remaining = TASKS
    /\ failed = 0
    /\ monitored = 0

FailNext ==
    /\ state = "failing"
    /\ IF USE_FIXED
          THEN /\ remaining' = remaining - 1
               /\ failed' = failed + 1
               /\ monitored' = monitored + 1
               /\ state' = IF remaining = 1 THEN "complete" ELSE "failing"
          ELSE /\ state' = "error"
               /\ remaining' = remaining - 1
               /\ failed' = failed + 1
               /\ monitored' = monitored + 1

Next == FailNext \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ state \in {"failing", "complete", "error"}
    /\ remaining \in 0..TASKS
    /\ failed \in 0..TASKS
    /\ monitored \in 0..TASKS

NoPendingAfterFailure == state = "error" => remaining = 0
MonitoringTerminality == state = "complete" => monitored = TASKS
FailureProgress == state = "complete" => failed = TASKS

================================================================================
