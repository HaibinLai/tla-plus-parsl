------------------------- MODULE ParslThreadExecutorShutdownMode -------------------------
EXTENDS Naturals

(***************************************************************************
 * ThreadPoolExecutor shutdown(wait) boundary.
 *
 * ``shutdown(wait=False)`` returns to Parsl while a running callable remains
 * alive and must finish.  The Current branch models the common but unsafe
 * interpretation that a returned shutdown means the worker is already gone;
 * the Fixed branch preserves the running callable until completion.
 ***************************************************************************)

CONSTANTS WAIT, USE_FIXED
TaskStates == {"pending", "running", "done"}
ExecutorStates == {"open", "returned", "closed"}

VARIABLES task, executor, workerAlive
vars == <<task, executor, workerAlive>>

Init ==
    /\ WAIT \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ task = "pending"
    /\ executor = "open"
    /\ workerAlive = TRUE

Start ==
    /\ task = "pending"
    /\ executor = "open"
    /\ task' = "running"
    /\ UNCHANGED <<executor, workerAlive>>

Shutdown ==
    /\ executor = "open"
    /\ executor' = IF task = "running" THEN "returned" ELSE "closed"
    /\ workerAlive' = IF WAIT
          THEN IF task = "running" THEN TRUE ELSE FALSE
          ELSE IF task = "running" /\ USE_FIXED THEN TRUE ELSE FALSE
    /\ UNCHANGED task

Finish ==
    /\ task = "running"
    /\ task' = "done"
    /\ executor' = IF executor = "returned" THEN "closed" ELSE executor
    /\ workerAlive' = FALSE

Next == Start \/ Shutdown \/ Finish \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ WAIT \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ task \in TaskStates
    /\ executor \in ExecutorStates
    /\ workerAlive \in BOOLEAN

RunningWorkerSafety == task = "running" => workerAlive
ShutdownTerminal == executor = "closed" => task # "running"
=============================================================================
