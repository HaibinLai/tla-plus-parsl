--------------------------- MODULE ParslAzureStatusBookkeepingFutureMonitoring ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Azure status bookkeeping composed with a logical Future and monitoring.
 * A translated RUNNING status must update the provider's local resource map;
 * otherwise a later completion can be detached from the state observed by
 * the Future/monitoring layer.
 ***************************************************************************)

CONSTANT USE_FIXED

PollStates == {"idle", "updated"}
Statuses == {"pending", "running"}
FutureStates == {"pending", "succeeded"}
MonitorStates == {"none", "succeeded"}

VARIABLES returned, local, pollState, future, monitor
vars == <<returned, local, pollState, future, monitor>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ returned = "pending"
    /\ local = "pending"
    /\ pollState = "idle"
    /\ future = "pending"
    /\ monitor = "none"

PollStatus ==
    /\ pollState = "idle"
    /\ returned' = "running"
    /\ local' = IF USE_FIXED THEN "running" ELSE local
    /\ pollState' = "updated"
    /\ UNCHANGED <<future, monitor>>

CompleteTask ==
    /\ pollState = "updated"
    /\ local = "running"
    /\ future' = "succeeded"
    /\ monitor' = "succeeded"
    /\ UNCHANGED <<returned, local, pollState>>

Next ==
    \/ PollStatus
    \/ CompleteTask
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ returned \in Statuses
    /\ local \in Statuses
    /\ pollState \in PollStates
    /\ future \in FutureStates
    /\ monitor \in MonitorStates

BookkeepingConsistency ==
    pollState = "updated" => local = returned

CompletionPropagation ==
    future = "succeeded" => local = "running" /\ monitor = "succeeded"

=============================================================================
