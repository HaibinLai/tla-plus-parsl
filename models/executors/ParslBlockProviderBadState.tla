--------------------------- MODULE ParslBlockProviderBadState ---------------------------
EXTENDS Naturals, FiniteSets

(***************************************************************************
 * Common BlockProviderExecutor failure semantics from
 * parsl/executors/status_handling.py.
 *
 * An unrecoverable provider/block error marks the executor bad, records the
 * cause, fails every outstanding task, and rejects later submissions. Tasks
 * that completed before the error remain terminal and are not rewritten.
 ***************************************************************************)

CONSTANT TASKS
STATES == {"absent", "pending", "succeeded", "failed"}

VARIABLES taskState, bad, exceptionRecorded, rejected
vars == <<taskState, bad, exceptionRecorded, rejected>>

Init ==
    /\ TASKS # {}
    /\ taskState = [t \in TASKS |-> "absent"]
    /\ bad = FALSE
    /\ exceptionRecorded = FALSE
    /\ rejected = [t \in TASKS |-> FALSE]

Submit(t) ==
    /\ t \in TASKS
    /\ taskState[t] = "absent"
    /\ ~bad
    /\ taskState' = [taskState EXCEPT ![t] = "pending"]
    /\ UNCHANGED <<bad, exceptionRecorded, rejected>>

RejectSubmit(t) ==
    /\ t \in TASKS
    /\ taskState[t] = "absent"
    /\ bad
    /\ rejected' = [rejected EXCEPT ![t] = TRUE]
    /\ UNCHANGED <<taskState, bad, exceptionRecorded>>

Complete(t) ==
    /\ t \in TASKS
    /\ taskState[t] = "pending"
    /\ ~bad
    /\ taskState' = [taskState EXCEPT ![t] = "succeeded"]
    /\ UNCHANGED <<bad, exceptionRecorded, rejected>>

MarkBad ==
    /\ ~bad
    /\ bad' = TRUE
    /\ exceptionRecorded' = TRUE
    /\ taskState' = [t \in TASKS |->
          IF taskState[t] = "pending" THEN "failed" ELSE taskState[t]]
    /\ UNCHANGED rejected

Next ==
    \/ \E t \in TASKS : Submit(t)
    \/ \E t \in TASKS : RejectSubmit(t)
    \/ \E t \in TASKS : Complete(t)
    \/ MarkBad
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ taskState \in [TASKS -> STATES]
    /\ bad \in BOOLEAN
    /\ exceptionRecorded \in BOOLEAN
    /\ rejected \in [TASKS -> BOOLEAN]

BadStateFailsOutstanding ==
    bad => \A t \in TASKS : taskState[t] # "pending"

BadStateIsTerminal ==
    bad => exceptionRecorded

RejectedOnlyAfterBad ==
    \A t \in TASKS : rejected[t] => bad

=============================================================================
