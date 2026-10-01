--------------------- MODULE ParslJoinProviderResultMonitoringDB ---------------------
EXTENDS Naturals, Integers, FiniteSets

(***************************************************************************
 * Join + provider retry + stale inner result + monitoring database.
 *
 * Two logical join dependencies are kept separate from their physical
 * attempts.  A provider loss moves the outer join to retry_wait and a retry
 * starts a new generation for both dependencies.  A late inner result from
 * generation zero must not satisfy generation one.  Terminal monitoring is
 * queued only after both current-generation dependencies are complete, and a
 * duplicate persistence event is idempotent in the Fixed branch.
 ***************************************************************************)

CONSTANTS DEPS, USE_FIXED, MAX_RETRIES

OuterStates == {"blocked", "running", "retry_wait", "done", "failed"}
DepStates == {"pending", "done"}
ProviderStates == {"active", "failed"}
CollectorStates == {"alive", "stopped"}
MonitorStates == {"none", "running", "retry", "succeeded", "failed"}
DBStates == {"none", "queued", "persisted"}

VARIABLES outer, generation, depState, resolvedAttempt,
          provider, collector, monitor, db, staleSeen
vars == <<outer, generation, depState, resolvedAttempt,
          provider, collector, monitor, db, staleSeen>>

Init ==
    /\ DEPS # {}
    /\ DEPS \subseteq STRING
    /\ MAX_RETRIES >= 1
    /\ outer = "blocked"
    /\ generation = 0
    /\ depState = [d \in DEPS |-> "pending"]
    /\ resolvedAttempt = [d \in DEPS |-> -1]
    /\ provider = "active"
    /\ collector = "alive"
    /\ monitor = "none"
    /\ db = "none"
    /\ staleSeen = FALSE

StartJoin ==
    /\ outer = "blocked"
    /\ provider = "active"
    /\ collector = "alive"
    /\ outer' = "running"
    /\ monitor' = "running"
    /\ UNCHANGED <<generation, depState, resolvedAttempt,
                    provider, collector, db, staleSeen>>

ProviderPollFailure ==
    /\ outer = "running"
    /\ provider = "active"
    /\ collector = "alive"
    /\ provider' = "failed"
    /\ collector' = "stopped"
    /\ IF USE_FIXED
          THEN /\ outer' = "retry_wait"
               /\ monitor' = "retry"
          ELSE /\ UNCHANGED <<outer, monitor>>
    /\ UNCHANGED <<generation, depState, resolvedAttempt, db, staleSeen>>

RetryJoin ==
    /\ outer = "retry_wait"
    /\ generation < MAX_RETRIES
    /\ outer' = "blocked"
    /\ generation' = generation + 1
    /\ depState' = [d \in DEPS |-> "pending"]
    /\ resolvedAttempt' = [d \in DEPS |-> -1]
    /\ provider' = "active"
    /\ collector' = "alive"
    /\ monitor' = "retry"
    /\ UNCHANGED <<db, staleSeen>>

CompleteDep(d) ==
    /\ outer = "running"
    /\ provider = "active"
    /\ collector = "alive"
    /\ d \in DEPS
    /\ depState[d] = "pending"
    /\ depState' = [depState EXCEPT ![d] = "done"]
    /\ resolvedAttempt' = [resolvedAttempt EXCEPT ![d] = generation]
    /\ IF \A x \in DEPS : (IF x = d THEN "done" ELSE depState[x]) = "done"
          THEN /\ outer' = "done"
               /\ monitor' = "succeeded"
          ELSE /\ UNCHANGED <<outer, monitor>>
    /\ UNCHANGED <<generation, provider, collector, db, staleSeen>>

LateDep(d) ==
    /\ generation > 0
    /\ outer \in {"blocked", "running", "retry_wait"}
    /\ d \in DEPS
    /\ depState[d] = "pending"
    /\ staleSeen' = TRUE
    /\ IF USE_FIXED
          THEN /\ UNCHANGED <<depState, resolvedAttempt, outer, monitor>>
          ELSE /\ depState' = [depState EXCEPT ![d] = "done"]
               /\ resolvedAttempt' = [resolvedAttempt EXCEPT ![d] = generation - 1]
               /\ UNCHANGED <<outer, monitor>>
    /\ UNCHANGED <<generation, provider, collector, db>>

QueueTerminalStatus ==
    /\ outer = "done"
    /\ monitor = "succeeded"
    /\ db = "none"
    /\ db' = "queued"
    /\ UNCHANGED <<outer, generation, depState, resolvedAttempt,
                    provider, collector, monitor, staleSeen>>

PersistTerminalStatus ==
    /\ db = "queued"
    /\ db' = "persisted"
    /\ UNCHANGED <<outer, generation, depState, resolvedAttempt,
                    provider, collector, monitor, staleSeen>>

DuplicatePersist ==
    /\ db = "persisted"
    /\ IF USE_FIXED
          THEN /\ UNCHANGED db
          ELSE /\ db' = "none"
    /\ UNCHANGED <<outer, generation, depState, resolvedAttempt,
                    provider, collector, monitor, staleSeen>>

Next ==
    \/ StartJoin
    \/ ProviderPollFailure
    \/ RetryJoin
    \/ \E d \in DEPS : CompleteDep(d)
    \/ \E d \in DEPS : LateDep(d)
    \/ QueueTerminalStatus
    \/ PersistTerminalStatus
    \/ DuplicatePersist
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ outer \in OuterStates
    /\ generation \in 0..MAX_RETRIES
    /\ depState \in [DEPS -> DepStates]
    /\ resolvedAttempt \in [DEPS -> -1..MAX_RETRIES]
    /\ provider \in ProviderStates
    /\ collector \in CollectorStates
    /\ monitor \in MonitorStates
    /\ db \in DBStates
    /\ staleSeen \in BOOLEAN

JoinAdmissionSafety ==
    outer = "running" => provider = "active" /\ collector = "alive"

FailureVisibility ==
    provider = "failed" => outer \in {"retry_wait", "failed"}

RetryBound == generation <= MAX_RETRIES

JoinResultSafety ==
    outer = "done"
        => /\ \A d \in DEPS : depState[d] = "done"
           /\ \A d \in DEPS : resolvedAttempt[d] = generation

MonitoringDatabaseSafety ==
    db = "persisted"
        => /\ outer = "done"
           /\ monitor = "succeeded"
           /\ \A d \in DEPS : resolvedAttempt[d] = generation

=============================================================================
