--------------------------- MODULE ParslJoinCancelRetryGeneration ---------------------------
EXTENDS Naturals, FiniteSets

(***************************************************************************
 * Two-dependency join composition.
 *
 * Each logical dependency has its own physical attempt.  One dependency may
 * fail and retry before the outer join is cancelled.  A result from that old
 * attempt can arrive after cancellation.  Fixed cancels every dependency and
 * ignores the stale result; Current lets the old result mutate a cancelled
 * dependency, violating join terminal-state and monitoring consistency.
 ***************************************************************************)

CONSTANT USE_FIXED

DEPS == {"left", "right"}
DepStates == {"pending", "succeeded", "cancelled"}
ProviderStates == {"running", "lost", "cancelled"}
OuterStates == {"running", "succeeded", "cancelled"}
LateStates == {"none", "accepted", "ignored"}
MonitorStates == {"none", "queued", "persisted"}
Statuses == {"none", "succeeded", "cancelled"}

VARIABLES depState, depAttempt, provider, outer,
          lateAttempt, lateResult, monitor, dbStatus
vars == <<depState, depAttempt, provider, outer,
          lateAttempt, lateResult, monitor, dbStatus>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ depState = [d \in DEPS |-> "pending"]
    /\ depAttempt = [d \in DEPS |-> 1]
    /\ provider = [d \in DEPS |-> "running"]
    /\ outer = "running"
    /\ lateAttempt = [d \in DEPS |-> 0]
    /\ lateResult = [d \in DEPS |-> "none"]
    /\ monitor = "none"
    /\ dbStatus = "none"

ProviderFailure(d) ==
    /\ d \in DEPS
    /\ outer = "running"
    /\ depAttempt[d] = 1
    /\ provider[d] = "running"
    /\ provider' = [provider EXCEPT ![d] = "lost"]
    /\ UNCHANGED <<depState, depAttempt, outer, lateAttempt,
                    lateResult, monitor, dbStatus>>

Retry(d) ==
    /\ d \in DEPS
    /\ outer = "running"
    /\ depAttempt[d] = 1
    /\ provider[d] = "lost"
    /\ depAttempt' = [depAttempt EXCEPT ![d] = 2]
    /\ provider' = [provider EXCEPT ![d] = "running"]
    /\ UNCHANGED <<depState, outer, lateAttempt, lateResult, monitor, dbStatus>>

Complete(d) ==
    /\ d \in DEPS
    /\ outer = "running"
    /\ depState[d] = "pending"
    /\ provider[d] = "running"
    /\ depState' = [depState EXCEPT ![d] = "succeeded"]
    /\ outer' = IF (\A x \in DEPS :
                         (x = d \/ depState[x] = "succeeded"))
                    THEN "succeeded" ELSE "running"
    /\ UNCHANGED <<depAttempt, provider, lateAttempt, lateResult,
                    monitor, dbStatus>>

CancelOuter ==
    /\ outer = "running"
    /\ outer' = "cancelled"
    /\ depState' = [d \in DEPS |-> "cancelled"]
    /\ provider' = [d \in DEPS |-> "cancelled"]
    /\ UNCHANGED <<depAttempt, lateAttempt, lateResult, monitor, dbStatus>>

LateOldResult(d) ==
    /\ d \in DEPS
    /\ outer = "cancelled"
    /\ depAttempt[d] = 2
    /\ depState[d] = "cancelled"
    /\ lateResult[d] = "none"
    /\ lateAttempt' = [lateAttempt EXCEPT ![d] = 1]
    /\ IF USE_FIXED
          THEN /\ lateResult' = [lateResult EXCEPT ![d] = "ignored"]
               /\ UNCHANGED depState
          ELSE /\ lateResult' = [lateResult EXCEPT ![d] = "accepted"]
               /\ depState' = [depState EXCEPT ![d] = "succeeded"]
    /\ UNCHANGED <<depAttempt, provider, outer, monitor, dbStatus>>

QueueMonitoring ==
    /\ outer # "running"
    /\ monitor = "none"
    /\ monitor' = "queued"
    /\ dbStatus' = outer
    /\ UNCHANGED <<depState, depAttempt, provider, outer,
                    lateAttempt, lateResult>>

PersistMonitoring ==
    /\ monitor = "queued"
    /\ monitor' = "persisted"
    /\ UNCHANGED <<depState, depAttempt, provider, outer,
                    lateAttempt, lateResult, dbStatus>>

Next ==
    \/ \E d \in DEPS : ProviderFailure(d)
    \/ \E d \in DEPS : Retry(d)
    \/ \E d \in DEPS : Complete(d)
    \/ CancelOuter
    \/ \E d \in DEPS : LateOldResult(d)
    \/ QueueMonitoring
    \/ PersistMonitoring
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ depState \in [DEPS -> DepStates]
    /\ depAttempt \in [DEPS -> 1..2]
    /\ provider \in [DEPS -> ProviderStates]
    /\ outer \in OuterStates
    /\ lateAttempt \in [DEPS -> 0..2]
    /\ lateResult \in [DEPS -> LateStates]
    /\ monitor \in MonitorStates
    /\ dbStatus \in Statuses

JoinCompletionSafety ==
    outer = "succeeded" => \A d \in DEPS : depState[d] = "succeeded"

JoinCancellationSafety ==
    outer = "cancelled" => \A d \in DEPS : depState[d] = "cancelled"

AttemptCorrelationSafety ==
    \A d \in DEPS : lateResult[d] = "accepted" => lateAttempt[d] = depAttempt[d]

MonitoringConsistency ==
    dbStatus # "none" => dbStatus = outer

=============================================================================
