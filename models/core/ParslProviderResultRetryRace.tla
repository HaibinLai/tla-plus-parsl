--------------------------- MODULE ParslProviderResultRetryRace ---------------------------
EXTENDS Naturals, Integers

(***************************************************************************
 * Provider failure + executor collector + retry + stale-result race.
 *
 * A logical task has a physical attempt.  A provider poll can make the
 * collector unavailable after the first attempt has started; the manager then
 * retries the logical task.  The old attempt's result may still arrive after
 * the retry is admitted.  USE_FIXED ignores that result and preserves the
 * attempt correlation, while the Current branch resolves the logical Future
 * with the stale attempt.
 ***************************************************************************)

CONSTANTS USE_FIXED, MAX_RETRIES

TaskStates == {"pending", "running", "retry_wait", "done", "failed"}
ProviderStates == {"active", "failed"}
CollectorStates == {"alive", "stopped"}
MonitorStates == {"none", "running", "retry", "succeeded", "failed"}

VARIABLES task, attempt, provider, collector, monitor,
          resolvedAttempt, staleSeen
vars == <<task, attempt, provider, collector, monitor,
          resolvedAttempt, staleSeen>>

Init ==
    /\ MAX_RETRIES >= 1
    /\ task = "pending"
    /\ attempt = 0
    /\ provider = "active"
    /\ collector = "alive"
    /\ monitor = "none"
    /\ resolvedAttempt = -1
    /\ staleSeen = FALSE

Submit ==
    /\ task = "pending"
    /\ provider = "active"
    /\ collector = "alive"
    /\ task' = "running"
    /\ monitor' = "running"
    /\ UNCHANGED <<attempt, provider, collector, resolvedAttempt, staleSeen>>

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
    /\ UNCHANGED <<attempt, resolvedAttempt, staleSeen>>

Retry ==
    /\ task = "retry_wait"
    /\ attempt < MAX_RETRIES
    /\ task' = "pending"
    /\ attempt' = attempt + 1
    /\ provider' = "active"
    /\ collector' = "alive"
    /\ monitor' = "retry"
    /\ UNCHANGED <<resolvedAttempt, staleSeen>>

CompleteCurrent ==
    /\ task = "running"
    /\ provider = "active"
    /\ collector = "alive"
    /\ task' = "done"
    /\ monitor' = "succeeded"
    /\ resolvedAttempt' = attempt
    /\ UNCHANGED <<attempt, provider, collector, staleSeen>>

LateResult(a) ==
    /\ a < attempt
    /\ task \in {"pending", "running", "retry_wait"}
    /\ staleSeen' = TRUE
    /\ IF USE_FIXED
          THEN /\ UNCHANGED <<task, monitor, resolvedAttempt>>
          ELSE /\ task' = "done"
               /\ monitor' = "succeeded"
               /\ resolvedAttempt' = a
    /\ UNCHANGED <<attempt, provider, collector>>

Next ==
    \/ Submit
    \/ ProviderPollFailure
    \/ Retry
    \/ CompleteCurrent
    \/ LateResult(0)
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ task \in TaskStates
    /\ attempt \in 0..MAX_RETRIES
    /\ provider \in ProviderStates
    /\ collector \in CollectorStates
    /\ monitor \in MonitorStates
    /\ resolvedAttempt \in -1..MAX_RETRIES
    /\ staleSeen \in BOOLEAN

AdmissionSafety ==
    task = "running" => provider = "active" /\ collector = "alive"

FailureVisibility ==
    provider = "failed" => task \in {"retry_wait", "failed"}

RetryBound == attempt <= MAX_RETRIES

StaleResultSafety ==
    task = "done" => resolvedAttempt = attempt

TerminalMonitoring ==
    monitor = "succeeded" => task = "done"

=============================================================================
