------------------------- MODULE ParslPoolExecutorMapShutdown -------------------------
EXTENDS Naturals, Sequences

(***************************************************************************
 * ParslPoolExecutor.map timeout followed by shutdown(cancel_futures=True).
 *
 * Parsl submits all map inputs eagerly and does not support cancellation.  A
 * timeout stops the result iterator, but neither that timeout nor advisory
 * shutdown may cancel the already-submitted Futures.  The Current branch
 * models the tempting concurrent.futures interpretation; Fixed preserves
 * pending work and allows its late completion.
 ***************************************************************************)

CONSTANT USE_FIXED
TASKS == {1, 2}
TaskStates == {"pending", "succeeded", "failed", "cancelled"}
PoolStates == {"open", "closed"}

VARIABLES task, pool, cursor, yielded, timedOut
vars == <<task, pool, cursor, yielded, timedOut>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ task = [i \in TASKS |-> "pending"]
    /\ pool = "open"
    /\ cursor = 1
    /\ yielded = <<>>
    /\ timedOut = FALSE

Complete(i) ==
    /\ i \in TASKS
    /\ task[i] = "pending"
    /\ task' = [task EXCEPT ![i] = "succeeded"]
    /\ UNCHANGED <<pool, cursor, yielded, timedOut>>

YieldNext ==
    /\ ~timedOut
    /\ \E i \in TASKS :
          /\ cursor = i
          /\ task[i] \in {"succeeded", "failed"}
          /\ yielded' = Append(yielded, i)
    /\ cursor' = cursor + 1
    /\ UNCHANGED <<task, pool, timedOut>>

Timeout ==
    /\ ~timedOut
    /\ \E i \in TASKS : cursor = i /\ task[i] = "pending"
    /\ timedOut' = TRUE
    /\ task' = IF USE_FIXED THEN task
               ELSE [i \in TASKS |-> IF task[i] = "pending" THEN "cancelled" ELSE task[i]]
    /\ UNCHANGED <<pool, cursor, yielded>>

Shutdown ==
    /\ pool = "open"
    /\ pool' = "closed"
    /\ task' = IF USE_FIXED THEN task
               ELSE [i \in TASKS |-> IF task[i] = "pending" THEN "cancelled" ELSE task[i]]
    /\ UNCHANGED <<cursor, yielded, timedOut>>

Next ==
    \/ \E i \in TASKS : Complete(i)
    \/ YieldNext
    \/ Timeout
    \/ Shutdown
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ task \in [TASKS -> TaskStates]
    /\ pool \in PoolStates
    /\ cursor \in 1..3
    /\ yielded \in Seq(TASKS)
    /\ timedOut \in BOOLEAN

TimeoutDoesNotCancel == timedOut => \A i \in TASKS : task[i] # "cancelled"
ShutdownDoesNotCancel == pool = "closed" => \A i \in TASKS : task[i] # "cancelled"
=============================================================================
