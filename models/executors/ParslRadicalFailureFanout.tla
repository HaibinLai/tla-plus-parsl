--------------------------- MODULE ParslRadicalFailureFanout ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Radical-Pilot executor failure fan-out.
 *
 * `_fail_all_tasks` completes each Future synchronously.  A Future callback
 * may remove its entry from `future_tasks` while the current implementation
 * is iterating the dictionary, aborting the sweep before later tasks fail.
 * USE_FIXED represents iterating a snapshot of task entries.
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

Next == FailNext \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in {"failing", "complete", "error"}
    /\ remaining \in 0..TASKS
    /\ failed \in 0..TASKS

MutationSafety == state = "error" => USE_FIXED
FailureProgress == state = "complete" => failed = TASKS

=============================================================================
