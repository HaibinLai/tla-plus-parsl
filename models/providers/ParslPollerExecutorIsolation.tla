--------------------------- MODULE ParslPollerExecutorIsolation ---------------------------
EXTENDS Naturals

(***************************************************************************
 * JobStatusPoller isolation across executors.
 *
 * JobStatusPoller.poll invokes each executor in sequence without a per-
 * executor exception boundary.  A transient provider/status exception from
 * one executor can therefore terminate the poll and skip all later
 * executors.  The fixed branch isolates the failure and continues polling.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES firstState, secondState, pollerAlive
vars == <<firstState, secondState, pollerAlive>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ firstState = "unpolled"
    /\ secondState = "unpolled"
    /\ pollerAlive = TRUE

PollFirstExecutor ==
    /\ pollerAlive
    /\ firstState = "unpolled"
    /\ firstState' = "failed"
    /\ IF USE_FIXED
          THEN pollerAlive' = TRUE
          ELSE pollerAlive' = FALSE
    /\ UNCHANGED secondState

PollSecondExecutor ==
    /\ pollerAlive
    /\ firstState = "failed"
    /\ secondState = "unpolled"
    /\ secondState' = "updated"
    /\ UNCHANGED <<firstState, pollerAlive>>

Next ==
    \/ PollFirstExecutor
    \/ PollSecondExecutor
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ firstState \in {"unpolled", "failed"}
    /\ secondState \in {"unpolled", "updated"}
    /\ pollerAlive \in BOOLEAN

IndependentExecutorProgress ==
    (firstState = "failed" /\ ~pollerAlive) => secondState = "updated"

=============================================================================
