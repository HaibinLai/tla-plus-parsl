--------------------------- MODULE ParslDependencyFailurePropagation ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Logical dependency failure in DataFlowKernel.
 *
 * A dependent task must wait for its upstream Future.  Once the Future is
 * terminal with an exception, _unwrap_futures creates a DependencyError and
 * launch_if_ready completes the dependent task as dep_fail.  It must not
 * submit a physical attempt or spend retry budget on an error that occurred
 * before the dependent task was launched.
 ***************************************************************************)

CONSTANTS MAX_RETRIES, USE_FIXED

UpstreamStates == {"pending", "running", "succeeded", "failed"}
DownstreamStates == {"pending", "waiting", "running", "retry_wait",
                     "succeeded", "dep_failed", "failed"}
FutureStates == {"unresolved", "resolved", "rejected"}

VARIABLES upstream, downstream, dependencyDone, dependencyError,
          attempts, future

vars == <<upstream, downstream, dependencyDone, dependencyError, attempts, future>>

Init ==
    /\ MAX_RETRIES >= 0
    /\ USE_FIXED \in BOOLEAN
    /\ upstream = "pending"
    /\ downstream = "pending"
    /\ dependencyDone = FALSE
    /\ dependencyError = FALSE
    /\ attempts = 0
    /\ future = "unresolved"

StartUpstream ==
    /\ upstream = "pending"
    /\ upstream' = "running"
    /\ downstream' = "waiting"
    /\ UNCHANGED <<dependencyDone, dependencyError, attempts, future>>

CompleteUpstream ==
    /\ upstream = "running"
    /\ downstream = "waiting"
    /\ upstream' = "succeeded"
    /\ dependencyDone' = TRUE
    /\ dependencyError' = FALSE
    /\ UNCHANGED <<downstream, attempts, future>>

FailUpstream ==
    /\ upstream = "running"
    /\ downstream = "waiting"
    /\ upstream' = "failed"
    /\ dependencyDone' = TRUE
    /\ dependencyError' = TRUE
    /\ UNCHANGED <<downstream, attempts, future>>

ReleaseAfterSuccess ==
    /\ downstream = "waiting"
    /\ dependencyDone
    /\ ~dependencyError
    /\ downstream' = "pending"
    /\ UNCHANGED <<upstream, dependencyDone, dependencyError, attempts, future>>

ResolveDependencyFailure ==
    /\ downstream = "waiting"
    /\ dependencyDone
    /\ dependencyError
    /\ downstream' = IF USE_FIXED THEN "dep_failed" ELSE "retry_wait"
    /\ attempts' = IF USE_FIXED THEN attempts ELSE attempts + 1
    /\ future' = IF USE_FIXED THEN "rejected" ELSE future
    /\ UNCHANGED <<upstream, dependencyDone, dependencyError>>

LaunchDependent ==
    /\ downstream = "pending"
    /\ dependencyDone
    /\ ~dependencyError
    /\ downstream' = "running"
    /\ attempts' = attempts + 1
    /\ UNCHANGED <<upstream, dependencyDone, dependencyError, future>>

RetryDependent ==
    /\ downstream = "retry_wait"
    /\ attempts < MAX_RETRIES
    /\ downstream' = "pending"
    /\ UNCHANGED <<upstream, dependencyDone, dependencyError, attempts, future>>

CompleteDependent ==
    /\ downstream = "running"
    /\ downstream' = "succeeded"
    /\ future' = "resolved"
    /\ UNCHANGED <<upstream, dependencyDone, dependencyError, attempts>>

RejectAfterRetry ==
    /\ downstream = "retry_wait"
    /\ attempts >= MAX_RETRIES
    /\ downstream' = "failed"
    /\ future' = "rejected"
    /\ UNCHANGED <<upstream, dependencyDone, dependencyError, attempts>>

Next ==
    \/ StartUpstream
    \/ CompleteUpstream
    \/ FailUpstream
    \/ ReleaseAfterSuccess
    \/ ResolveDependencyFailure
    \/ LaunchDependent
    \/ RetryDependent
    \/ CompleteDependent
    \/ RejectAfterRetry
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ upstream \in UpstreamStates
    /\ downstream \in DownstreamStates
    /\ dependencyDone \in BOOLEAN
    /\ dependencyError \in BOOLEAN
    /\ attempts \in 0..(MAX_RETRIES + 1)
    /\ future \in FutureStates

DependencySafety ==
    downstream = "dep_failed" =>
        /\ upstream = "failed"
        /\ dependencyError
        /\ attempts = 0
        /\ future = "rejected"

NoLaunchAfterDependencyFailure ==
    dependencyError => attempts = 0

RetryBound == attempts <= MAX_RETRIES

TerminalStateStability ==
    downstream \in {"succeeded", "dep_failed", "failed"} =>
        future \in {"resolved", "rejected"}

=============================================================================
SPECIFICATION Spec

INVARIANTS
    TypeOK
    DependencySafety
    NoLaunchAfterDependencyFailure
    RetryBound
    TerminalStateStability
