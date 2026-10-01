--------------------------- MODULE ParslStageInAttemptGeneration ---------------------------
EXTENDS Naturals, FiniteSets

(***************************************************************************
 * Logical task retries must be separated from physical stage-in attempts.
 * A transfer started for task attempt 0 can complete after the task has
 * retried as attempt 1.  The current branch lets that late transfer publish
 * readiness for the new attempt; the fixed branch accepts completion only
 * when the transfer generation matches the current logical attempt.
 ***************************************************************************)

CONSTANT USE_FIXED

ATTEMPTS == 0..1
TransferStates == {"idle", "copying", "failed", "done"}
TaskStates == {"pending", "ready"}

VARIABLES taskAttempt, transferState, completedAttempt, taskState
vars == <<taskAttempt, transferState, completedAttempt, taskState>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ taskAttempt = 0
    /\ transferState = [a \in ATTEMPTS |-> "idle"]
    /\ completedAttempt = "none"
    /\ taskState = "pending"

BeginTransfer(a) ==
    /\ a = taskAttempt
    /\ transferState[a] = "idle"
    /\ transferState' = [transferState EXCEPT ![a] = "copying"]
    /\ UNCHANGED <<taskAttempt, completedAttempt, taskState>>

FailTransfer(a) ==
    /\ transferState[a] = "copying"
    /\ transferState' = [transferState EXCEPT ![a] = "failed"]
    /\ IF a = taskAttempt /\ taskAttempt < 1
          THEN taskAttempt' = taskAttempt + 1
          ELSE UNCHANGED taskAttempt
    /\ UNCHANGED <<completedAttempt, taskState>>

RetryTask ==
    /\ taskAttempt = 0
    /\ transferState[0] = "copying"
    /\ taskAttempt' = 1
    /\ UNCHANGED <<transferState, completedAttempt, taskState>>

CompleteTransfer(a) ==
    /\ transferState[a] = "copying"
    /\ transferState' = [transferState EXCEPT ![a] = "done"]
    /\ IF USE_FIXED /\ a # taskAttempt
          THEN UNCHANGED <<completedAttempt, taskState>>
          ELSE /\ completedAttempt' = IF a = 0 THEN "0" ELSE "1"
               /\ taskState' = "ready"
    /\ UNCHANGED taskAttempt

Next ==
    \/ \E a \in ATTEMPTS : BeginTransfer(a)
    \/ \E a \in ATTEMPTS : FailTransfer(a)
    \/ RetryTask
    \/ \E a \in ATTEMPTS : CompleteTransfer(a)
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ taskAttempt \in ATTEMPTS
    /\ transferState \in [ATTEMPTS -> TransferStates]
    /\ completedAttempt \in {"none", "0", "1"}
    /\ taskState \in TaskStates

CurrentAttemptReadiness ==
    taskState = "ready" => completedAttempt = (IF taskAttempt = 0 THEN "0" ELSE "1")

=============================================================================
