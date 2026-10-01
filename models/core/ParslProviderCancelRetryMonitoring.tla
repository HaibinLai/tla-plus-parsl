--------------------------- MODULE ParslProviderCancelRetryMonitoring ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Provider failure/retry/cancellation composition.
 *
 * The logical task has two possible physical attempts.  Attempt 1 is lost,
 * attempt 2 is provisioned, and the task is then cancelled.  A result from
 * attempt 1 may arrive after cancellation.  Fixed rejects that stale result
 * and keeps the cancelled Future/monitoring row stable; Current accepts it
 * as success and violates terminal-state and attempt-correlation safety.
 ***************************************************************************)

CONSTANT USE_FIXED

TaskStates == {"running", "cancelled", "succeeded"}
ProviderStates == {"running", "lost", "cancelled"}
FutureStates == {"pending", "cancelled", "succeeded"}
LateStates == {"none", "accepted", "ignored"}
MonitorStates == {"none", "queued", "persisted"}
Statuses == {"none", "cancelled", "succeeded"}

VARIABLES task, attempt, provider, future,
          lateAttempt, lateResult, monitor, dbStatus
vars == <<task, attempt, provider, future,
          lateAttempt, lateResult, monitor, dbStatus>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ task = "running"
    /\ attempt = 1
    /\ provider = "running"
    /\ future = "pending"
    /\ lateAttempt = 0
    /\ lateResult = "none"
    /\ monitor = "none"
    /\ dbStatus = "none"

ProviderFailure ==
    /\ task = "running"
    /\ attempt = 1
    /\ provider = "running"
    /\ provider' = "lost"
    /\ UNCHANGED <<task, attempt, future, lateAttempt, lateResult,
                    monitor, dbStatus>>

Retry ==
    /\ task = "running"
    /\ attempt = 1
    /\ provider = "lost"
    /\ attempt' = 2
    /\ provider' = "running"
    /\ UNCHANGED <<task, future, lateAttempt, lateResult, monitor, dbStatus>>

Cancel ==
    /\ task = "running"
    /\ attempt = 2
    /\ provider = "running"
    /\ task' = "cancelled"
    /\ provider' = "cancelled"
    /\ IF USE_FIXED
          THEN future' = "cancelled"
          ELSE UNCHANGED future
    /\ UNCHANGED <<attempt, lateAttempt, lateResult, monitor, dbStatus>>

LateAttemptOneResult ==
    /\ task = "cancelled"
    /\ attempt = 2
    /\ provider = "cancelled"
    /\ lateResult = "none"
    /\ lateAttempt' = 1
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
    /\ UNCHANGED <<task, attempt, provider, future, lateAttempt, lateResult>>

PersistMonitoring ==
    /\ monitor = "queued"
    /\ monitor' = "persisted"
    /\ UNCHANGED <<task, attempt, provider, future,
                    lateAttempt, lateResult, dbStatus>>

Next ==
    \/ ProviderFailure
    \/ Retry
    \/ Cancel
    \/ LateAttemptOneResult
    \/ QueueMonitoring
    \/ PersistMonitoring
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ task \in TaskStates
    /\ attempt \in 1..2
    /\ provider \in ProviderStates
    /\ future \in FutureStates
    /\ lateAttempt \in 0..2
    /\ lateResult \in LateStates
    /\ monitor \in MonitorStates
    /\ dbStatus \in Statuses

CancellationFutureConsistency ==
    task = "cancelled" => future = "cancelled"

AttemptCorrelationSafety ==
    lateResult = "accepted" => lateAttempt = attempt

TerminalStateStability ==
    task = "cancelled" => lateResult # "accepted"

MonitoringConsistency ==
    dbStatus # "none" => dbStatus = task

=============================================================================
