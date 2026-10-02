--------------------------- MODULE ParslJoinBodyRetryMonitoring ---------------------------
EXTENDS Naturals

(***************************************************************************
 * join_app body retry composed with inner-Future admission and monitoring.
 *
 * A physical execution of the join body may fail before it returns the
 * inner Future.  A retryable failure must not terminate the outer Future or
 * monitoring row; the join callback is installed only after a successful
 * body result.  The fixed branch preserves that boundary and publishes the
 * terminal success after the admitted inner Future completes.
 ***************************************************************************)

CONSTANTS MAX_RETRIES, USE_FIXED

BodyStates == {"pending", "running", "retrying", "joining", "failed"}
OuterStates == {"pending", "joining", "succeeded", "failed"}
InnerStates == {"absent", "pending", "done"}
MonitorStates == {"none", "succeeded", "failed"}

VARIABLES body, outer, inner, attempts, joinInstalled, monitor
vars == <<body, outer, inner, attempts, joinInstalled, monitor>>

Init ==
    /\ MAX_RETRIES >= 1
    /\ USE_FIXED \in BOOLEAN
    /\ body = "pending"
    /\ outer = "pending"
    /\ inner = "absent"
    /\ attempts = 0
    /\ joinInstalled = FALSE
    /\ monitor = "none"

StartBody ==
    /\ body = "pending"
    /\ body' = "running"
    /\ UNCHANGED <<outer, inner, attempts, joinInstalled, monitor>>

BodyFailsRetryable ==
    /\ body = "running"
    /\ attempts < MAX_RETRIES
    /\ body' = "retrying"
    /\ attempts' = attempts + 1
    /\ IF USE_FIXED
          THEN /\ outer' = "pending"
               /\ monitor' = "none"
          ELSE /\ outer' = "failed"
               /\ monitor' = "failed"
    /\ UNCHANGED <<inner, joinInstalled>>

RetryBody ==
    /\ body = "retrying"
    /\ body' = "running"
    /\ UNCHANGED <<outer, inner, attempts, joinInstalled, monitor>>

BodyFailsFinally ==
    /\ body = "running"
    /\ attempts = MAX_RETRIES
    /\ body' = "failed"
    /\ outer' = "failed"
    /\ monitor' = "failed"
    /\ UNCHANGED <<inner, attempts, joinInstalled>>

BodyReturnsInner ==
    /\ body = "running"
    /\ body' = "joining"
    /\ outer' = "joining"
    /\ inner' = "pending"
    /\ joinInstalled' = TRUE
    /\ UNCHANGED <<attempts, monitor>>

InnerCompletes ==
    /\ body = "joining"
    /\ outer = "joining"
    /\ inner = "pending"
    /\ inner' = "done"
    /\ outer' = "succeeded"
    /\ monitor' = "succeeded"
    /\ UNCHANGED <<body, attempts, joinInstalled>>

Next ==
    \/ StartBody
    \/ BodyFailsRetryable
    \/ RetryBody
    \/ BodyFailsFinally
    \/ BodyReturnsInner
    \/ InnerCompletes
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ MAX_RETRIES >= 1
    /\ USE_FIXED \in BOOLEAN
    /\ body \in BodyStates
    /\ outer \in OuterStates
    /\ inner \in InnerStates
    /\ attempts \in 0..MAX_RETRIES
    /\ joinInstalled \in BOOLEAN
    /\ monitor \in MonitorStates

RetryBoundSafety == attempts <= MAX_RETRIES

RetryDoesNotTerminate ==
    body = "retrying" =>
        /\ outer = "pending"
        /\ monitor = "none"

JoinAdmissionSafety ==
    joinInstalled =>
        /\ body = "joining"
        /\ outer \in {"joining", "succeeded"}

TerminalMonitoringSafety ==
    outer = "succeeded" => /\ inner = "done" /\ monitor = "succeeded"

=============================================================================
