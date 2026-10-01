------------------------- MODULE ParslProviderResultMonitoringDB -------------------------
EXTENDS Naturals, Integers

(***************************************************************************
 * Provider retry, stale results, and monitoring persistence.
 *
 * This companion keeps the physical-attempt correlation from
 * ParslProviderResultRetryRace and adds the asynchronous monitoring queue and
 * database.  A terminal status is queued only after the logical task resolves
 * with the current attempt.  The fixed branch makes duplicate persistence
 * idempotent; the Current branch permits a duplicate write to erase the
 * terminal row.
 ***************************************************************************)

CONSTANTS USE_FIXED, MAX_RETRIES

TaskStates == {"pending", "running", "retry_wait", "done", "failed"}
ProviderStates == {"active", "failed"}
CollectorStates == {"alive", "stopped"}
MonitorStates == {"none", "running", "retry", "succeeded", "failed"}
DBStates == {"none", "queued", "persisted"}

VARIABLES task, attempt, provider, collector, monitor, db,
          resolvedAttempt, staleSeen
vars == <<task, attempt, provider, collector, monitor, db,
           resolvedAttempt, staleSeen>>

Init ==
    /\ MAX_RETRIES >= 1
    /\ task = "pending"
    /\ attempt = 0
    /\ provider = "active"
    /\ collector = "alive"
    /\ monitor = "none"
    /\ db = "none"
    /\ resolvedAttempt = -1
    /\ staleSeen = FALSE

Submit ==
    /\ task = "pending"
    /\ provider = "active"
    /\ collector = "alive"
    /\ task' = "running"
    /\ monitor' = "running"
    /\ UNCHANGED <<attempt, provider, collector, db,
                    resolvedAttempt, staleSeen>>

ProviderPollFailure ==
    /\ task = "running"
    /\ provider = "active"
    /\ collector = "alive"
    /\ provider' = "failed"
    /\ collector' = "stopped"
    /\ IF USE_FIXED
          THEN /\ task' = "retry_wait"
               /\ monitor' = "retry"
          ELSE /\ UNCHANGED <<task, monitor>>
    /\ UNCHANGED <<attempt, db, resolvedAttempt, staleSeen>>

Retry ==
    /\ task = "retry_wait"
    /\ attempt < MAX_RETRIES
    /\ task' = "pending"
    /\ attempt' = attempt + 1
    /\ provider' = "active"
    /\ collector' = "alive"
    /\ monitor' = "retry"
    /\ UNCHANGED <<db, resolvedAttempt, staleSeen>>

CompleteCurrent ==
    /\ task = "running"
    /\ provider = "active"
    /\ collector = "alive"
    /\ task' = "done"
    /\ monitor' = "succeeded"
    /\ resolvedAttempt' = attempt
    /\ UNCHANGED <<attempt, provider, collector, db, staleSeen>>

LateResult(a) ==
    /\ a < attempt
    /\ task \in {"pending", "running", "retry_wait"}
    /\ staleSeen' = TRUE
    /\ IF USE_FIXED
          THEN /\ UNCHANGED <<task, monitor, resolvedAttempt>>
          ELSE /\ task' = "done"
               /\ monitor' = "succeeded"
               /\ resolvedAttempt' = a
    /\ UNCHANGED <<attempt, provider, collector, db>>

QueueTerminalStatus ==
    /\ task = "done"
    /\ monitor = "succeeded"
    /\ resolvedAttempt = attempt
    /\ db = "none"
    /\ db' = "queued"
    /\ UNCHANGED <<task, attempt, provider, collector, monitor,
                    resolvedAttempt, staleSeen>>

PersistTerminalStatus ==
    /\ db = "queued"
    /\ db' = "persisted"
    /\ UNCHANGED <<task, attempt, provider, collector, monitor,
                    resolvedAttempt, staleSeen>>

DuplicatePersist ==
    /\ db = "persisted"
    /\ IF USE_FIXED
          THEN /\ UNCHANGED db
          ELSE /\ db' = "none"
    /\ UNCHANGED <<task, attempt, provider, collector, monitor,
                    resolvedAttempt, staleSeen>>

Next ==
    \/ Submit
    \/ ProviderPollFailure
    \/ Retry
    \/ CompleteCurrent
    \/ LateResult(0)
    \/ QueueTerminalStatus
    \/ PersistTerminalStatus
    \/ DuplicatePersist
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ task \in TaskStates
    /\ attempt \in 0..MAX_RETRIES
    /\ provider \in ProviderStates
    /\ collector \in CollectorStates
    /\ monitor \in MonitorStates
    /\ db \in DBStates
    /\ resolvedAttempt \in -1..MAX_RETRIES
    /\ staleSeen \in BOOLEAN

AdmissionSafety ==
    task = "running" => provider = "active" /\ collector = "alive"

FailureVisibility ==
    provider = "failed" => task \in {"retry_wait", "failed"}

RetryBound == attempt <= MAX_RETRIES

StaleResultSafety ==
    task = "done" => resolvedAttempt = attempt

MonitoringDatabaseSafety ==
    db = "persisted"
        => /\ task = "done"
           /\ monitor = "succeeded"
           /\ resolvedAttempt = attempt

=============================================================================
