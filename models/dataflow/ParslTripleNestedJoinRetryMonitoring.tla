--------------------------- MODULE ParslTripleNestedJoinRetryMonitoring ---------------------------
EXTENDS Naturals, Integers

(***************************************************************************
 * Three-level join composition with a retried inner join.  Leaves A/B feed
 * J1, J1 and leaf C feed J2, and J2 resolves the root join Future.  A result
 * from J1's failed physical attempt is late after retry; only the current
 * generation may satisfy the outer join and its monitoring record.
 ***************************************************************************)

CONSTANTS MAX_ATTEMPTS, USE_FIXED

J1States == {"pending", "running", "retry_wait", "failed", "succeeded", "stale"}
J2States == {"pending", "succeeded", "failed"}
RootStates == {"pending", "succeeded", "failed"}
MonitorStates == {"none", "succeeded", "failed"}
FutureStates == {"pending", "succeeded", "failed"}

VARIABLES currentAttempt, j1, resolvedAttempt, j2, root, future, monitor,
          staleSeen
vars == <<currentAttempt, j1, resolvedAttempt, j2, root, future, monitor,
           staleSeen>>

Init ==
    /\ MAX_ATTEMPTS >= 1
    /\ USE_FIXED \in BOOLEAN
    /\ currentAttempt = 0
    /\ j1 = "pending"
    /\ resolvedAttempt = -1
    /\ j2 = "pending"
    /\ root = "pending"
    /\ future = "pending"
    /\ monitor = "none"
    /\ staleSeen = FALSE

StartJ1 ==
    /\ j1 \in {"pending", "retry_wait"}
    /\ j1' = "running"
    /\ UNCHANGED <<currentAttempt, resolvedAttempt, j2, root, future,
                    monitor, staleSeen>>

FailJ1 ==
    /\ j1 = "running"
    /\ j1' = IF currentAttempt < MAX_ATTEMPTS THEN "retry_wait" ELSE "failed"
    /\ UNCHANGED <<currentAttempt, resolvedAttempt, j2, root, future,
                    monitor, staleSeen>>

RetryJ1 ==
    /\ j1 = "retry_wait"
    /\ currentAttempt < MAX_ATTEMPTS
    /\ currentAttempt' = currentAttempt + 1
    /\ j1' = "pending"
    /\ UNCHANGED <<resolvedAttempt, j2, root, future, monitor, staleSeen>>

CompleteCurrentJ1 ==
    /\ j1 = "running"
    /\ j1' = "succeeded"
    /\ resolvedAttempt' = currentAttempt
    /\ UNCHANGED <<currentAttempt, j2, root, future, monitor, staleSeen>>

LateJ1Completion(a) ==
    /\ a \in 0..MAX_ATTEMPTS
    /\ a < currentAttempt
    /\ j1 \in {"pending", "running", "retry_wait"}
    /\ IF USE_FIXED
          THEN /\ staleSeen' = TRUE
               /\ UNCHANGED <<j1, resolvedAttempt>>
          ELSE /\ j1' = "succeeded"
               /\ resolvedAttempt' = a
               /\ UNCHANGED staleSeen
    /\ UNCHANGED <<currentAttempt, j2, root, future, monitor>>

EvaluateJ2 ==
    /\ j2 = "pending"
    /\ j1 = "succeeded"
    /\ j2' = "succeeded"
    /\ UNCHANGED <<currentAttempt, j1, resolvedAttempt, root, future,
                    monitor, staleSeen>>

FinalizeRoot ==
    /\ root = "pending"
    /\ j2 = "succeeded"
    /\ root' = "succeeded"
    /\ future' = "succeeded"
    /\ monitor' = "succeeded"
    /\ UNCHANGED <<currentAttempt, j1, resolvedAttempt, j2, staleSeen>>

Next ==
    \/ StartJ1
    \/ FailJ1
    \/ RetryJ1
    \/ CompleteCurrentJ1
    \/ \E a \in 0..MAX_ATTEMPTS : LateJ1Completion(a)
    \/ EvaluateJ2
    \/ FinalizeRoot
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ currentAttempt \in 0..MAX_ATTEMPTS
    /\ j1 \in J1States
    /\ resolvedAttempt \in -1..MAX_ATTEMPTS
    /\ j2 \in J2States
    /\ root \in RootStates
    /\ future \in FutureStates
    /\ monitor \in MonitorStates
    /\ staleSeen \in BOOLEAN

CurrentAttemptSafety ==
    root = "succeeded" => resolvedAttempt = currentAttempt

NestedDependencySafety ==
    j2 = "succeeded" => j1 = "succeeded"

RootPropagationSafety ==
    root = "succeeded" => future = "succeeded" /\ monitor = "succeeded"

StaleResultSafety ==
    staleSeen => USE_FIXED

=============================================================================
