------------------------- MODULE ParslPollerExecutorFutureIsolation -------------------------
EXTENDS Naturals

(***************************************************************************
 * Provider poll failure must not strand an independent executor Future.
 *
 * The status poller visits executors sequentially.  One provider exception
 * may terminate the current callback, but it must not prevent a healthy
 * executor from publishing a terminal result for its own logical task.
 ***************************************************************************)

CONSTANT USE_FIXED

FutureStates == {"pending", "failed", "succeeded"}

VARIABLES firstFuture, secondFuture, pollerAlive
vars == <<firstFuture, secondFuture, pollerAlive>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ firstFuture = "pending"
    /\ secondFuture = "pending"
    /\ pollerAlive = TRUE

PollFailingExecutor ==
    /\ pollerAlive
    /\ firstFuture = "pending"
    /\ firstFuture' = "failed"
    /\ pollerAlive' = IF USE_FIXED THEN TRUE ELSE FALSE
    /\ UNCHANGED secondFuture

PollHealthyExecutor ==
    /\ pollerAlive
    /\ firstFuture = "failed"
    /\ secondFuture = "pending"
    /\ secondFuture' = "succeeded"
    /\ UNCHANGED <<firstFuture, pollerAlive>>

Next ==
    \/ PollFailingExecutor
    \/ PollHealthyExecutor
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ firstFuture \in FutureStates
    /\ secondFuture \in FutureStates
    /\ pollerAlive \in BOOLEAN

IndependentFutureTerminality ==
    firstFuture = "failed" /\ ~pollerAlive => secondFuture = "succeeded"

=============================================================================
