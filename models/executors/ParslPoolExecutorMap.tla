--------------------------- MODULE ParslPoolExecutorMap ---------------------------
EXTENDS Naturals, Sequences, FiniteSets

(***************************************************************************
 * ParslPoolExecutor.map result-iterator contract.
 *
 * Parsl submits every input eagerly, then consumes the returned Futures in
 * input order.  A timeout is a deadline for the iterator; it does not cancel
 * the already-submitted Parsl tasks.  A task may therefore finish after the
 * iterator has timed out.
 ***************************************************************************)

CONSTANT MAX_TASKS, DEADLINE

TASKS == 1..MAX_TASKS
TaskStates == {"pending", "succeeded", "failed"}

VARIABLES taskState, clock, cursor, yielded, timedOut
vars == <<taskState, clock, cursor, yielded, timedOut>>

Init ==
    /\ MAX_TASKS >= 1
    /\ DEADLINE >= 0
    /\ taskState = [i \in TASKS |-> "pending"]
    /\ clock = 0
    /\ cursor = 1
    /\ yielded = <<>>
    /\ timedOut = FALSE

AdvanceTime ==
    /\ ~timedOut
    /\ clock < DEADLINE
    /\ clock' = clock + 1
    /\ UNCHANGED <<taskState, cursor, yielded, timedOut>>

Complete(i) ==
    /\ i \in TASKS
    /\ taskState[i] = "pending"
    /\ taskState' = [taskState EXCEPT ![i] = "succeeded"]
    /\ UNCHANGED <<clock, cursor, yielded, timedOut>>

Fail(i) ==
    /\ i \in TASKS
    /\ taskState[i] = "pending"
    /\ taskState' = [taskState EXCEPT ![i] = "failed"]
    /\ UNCHANGED <<clock, cursor, yielded, timedOut>>

YieldNext ==
    /\ ~timedOut
    /\ cursor <= MAX_TASKS
    /\ taskState[cursor] \in {"succeeded", "failed"}
    /\ yielded' = Append(yielded, cursor)
    /\ cursor' = cursor + 1
    /\ UNCHANGED <<taskState, clock, timedOut>>

Timeout ==
    /\ ~timedOut
    /\ cursor <= MAX_TASKS
    /\ taskState[cursor] = "pending"
    /\ clock >= DEADLINE
    /\ timedOut' = TRUE
    /\ UNCHANGED <<taskState, clock, cursor, yielded>>

Next ==
    \/ AdvanceTime
    \/ \E i \in TASKS : Complete(i)
    \/ \E i \in TASKS : Fail(i)
    \/ YieldNext
    \/ Timeout
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ taskState \in [TASKS -> TaskStates]
    /\ clock \in Nat
    /\ cursor \in 1..(MAX_TASKS + 1)
    /\ yielded \in Seq(TASKS)
    /\ timedOut \in BOOLEAN

YieldOrder ==
    yielded = [i \in 1..Len(yielded) |-> i]

NoDuplicateYield ==
    Len(yielded) = Cardinality({yielded[i] : i \in 1..Len(yielded)})

TimeoutDoesNotCancel ==
    timedOut => \A i \in TASKS : taskState[i] # "cancelled"

LateCompletionAllowed ==
    timedOut /\ cursor <= MAX_TASKS =>
        taskState[cursor] = "pending" \/ taskState[cursor] = "succeeded" \/ taskState[cursor] = "failed"

=============================================================================
