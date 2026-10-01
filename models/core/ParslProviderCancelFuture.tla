--------------------------- MODULE ParslProviderCancelFuture ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Small cross-component cancellation model.
 *
 * A logical task owns one physical attempt.  Provider cancellation may race
 * with a result already in flight.  The Fixed branch terminally cancels the
 * Future and ignores a result from the cancelled attempt; the Current branch
 * leaves the Future pending and can publish the late result as success.
 * Monitoring is queued only after a terminal logical state and is persisted
 * with that terminal status.
 ***************************************************************************)

CONSTANT USE_FIXED

TaskStates == {"running", "cancelled", "succeeded"}
ProviderStates == {"running", "cancelled", "completed"}
FutureStates == {"pending", "cancelled", "succeeded"}
LateStates == {"none", "accepted", "ignored"}
MonitorStates == {"none", "queued", "persisted"}
Statuses == {"none", "cancelled", "succeeded"}

VARIABLES task, attempt, provider, future, lateResult,
          monitor, dbStatus
vars == <<task, attempt, provider, future, lateResult, monitor, dbStatus>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ task = "running"
    /\ attempt = 1
    /\ provider = "running"
    /\ future = "pending"
    /\ lateResult = "none"
    /\ monitor = "none"
    /\ dbStatus = "none"

Cancel ==
    /\ task = "running"
    /\ provider = "running"
    /\ provider' = "cancelled"
    /\ task' = "cancelled"
    /\ IF USE_FIXED
          THEN future' = "cancelled"
          ELSE UNCHANGED future
    /\ UNCHANGED <<attempt, lateResult, monitor, dbStatus>>

ProviderCompletes ==
    /\ provider = "running"
    /\ provider' = "completed"
    /\ UNCHANGED <<task, attempt, future, lateResult, monitor, dbStatus>>

LateResult ==
    /\ provider = "cancelled"
    /\ lateResult = "none"
    /\ IF USE_FIXED
          THEN /\ lateResult' = "ignored"
               /\ UNCHANGED <<task, future>>
          ELSE /\ lateResult' = "accepted"
               /\ task' = "succeeded"
               /\ future' = "succeeded"
    /\ UNCHANGED <<attempt, provider, monitor, dbStatus>>

QueueMonitoring ==
    /\ task # "running"
    /\ monitor = "none"
    /\ monitor' = "queued"
    /\ dbStatus' = task
    /\ UNCHANGED <<task, attempt, provider, future, lateResult>>

PersistMonitoring ==
    /\ monitor = "queued"
    /\ monitor' = "persisted"
    /\ UNCHANGED <<task, attempt, provider, future, lateResult, dbStatus>>

Next ==
    \/ Cancel
    \/ ProviderCompletes
    \/ LateResult
    \/ QueueMonitoring
    \/ PersistMonitoring
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ task \in TaskStates
    /\ attempt = 1
    /\ provider \in ProviderStates
    /\ future \in FutureStates
    /\ lateResult \in LateStates
    /\ monitor \in MonitorStates
    /\ dbStatus \in Statuses

CancellationFutureConsistency ==
    task = "cancelled" => future = "cancelled"

TerminalStateStability ==
    task = "cancelled" => lateResult # "accepted"

MonitoringConsistency ==
    dbStatus # "none" => dbStatus = task

=============================================================================
