--------------------------- MODULE ParslBadStateTaskMutation ---------------------------
EXTENDS Naturals

(***************************************************************************
 * set_bad_state_and_fail_all iterates the task dictionary and completes each
 * Future synchronously. A Future callback may remove its task entry while the
 * iteration is active, which makes Python raise RuntimeError. The fixed branch
 * snapshots the task keys before completing Futures.
 ***************************************************************************)

CONSTANT USE_FIXED
TASKS == 2

VARIABLES state, remaining, failed
vars == <<state, remaining, failed>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ state = "failing"
    /\ remaining = TASKS
    /\ failed = 0

FailNext ==
    /\ state = "failing"
    /\ IF USE_FIXED
          THEN /\ failed' = failed + 1
               /\ remaining' = remaining - 1
               /\ state' = IF remaining = 1 THEN "complete" ELSE "failing"
          ELSE /\ state' = "error"
               /\ UNCHANGED <<remaining, failed>>

Next ==
    \/ FailNext
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in {"failing", "complete", "error"}
    /\ remaining \in 0..TASKS
    /\ failed \in 0..TASKS

MutationSafety == state = "error" => USE_FIXED
FailureProgress == state = "complete" => failed = TASKS

=============================================================================
