--------------------------- MODULE ParslJoinBodyRetry ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Retry of the join_app body before a join handle is installed.
 *
 * The join body's physical execution can fail and consume a retry.  The outer
 * task enters `joining` only after a successful body result supplies an inner
 * Future; inner completion then determines the final outer result.
 ***************************************************************************)

CONSTANT MAX_RETRIES

OuterStates == {"pending", "running", "joining", "succeeded", "failed"}
InnerStates == {"absent", "pending", "done"}

VARIABLES outer, inner, attempts, joinInstalled
vars == <<outer, inner, attempts, joinInstalled>>

Init ==
    /\ MAX_RETRIES >= 0
    /\ outer = "pending"
    /\ inner = "absent"
    /\ attempts = 0
    /\ joinInstalled = FALSE

StartBody ==
    /\ outer = "pending"
    /\ outer' = "running"
    /\ UNCHANGED <<inner, attempts, joinInstalled>>

BodyFailsRetryable ==
    /\ outer = "running"
    /\ attempts < MAX_RETRIES
    /\ outer' = "pending"
    /\ attempts' = attempts + 1
    /\ UNCHANGED <<inner, joinInstalled>>

BodyFailsFinally ==
    /\ outer = "running"
    /\ attempts = MAX_RETRIES
    /\ outer' = "failed"
    /\ UNCHANGED <<inner, attempts, joinInstalled>>

BodyReturnsInner ==
    /\ outer = "running"
    /\ outer' = "joining"
    /\ inner' = "pending"
    /\ joinInstalled' = TRUE
    /\ UNCHANGED attempts

InnerCompletes ==
    /\ outer = "joining"
    /\ inner = "pending"
    /\ inner' = "done"
    /\ outer' = "succeeded"
    /\ UNCHANGED <<attempts, joinInstalled>>

Next ==
    \/ StartBody
    \/ BodyFailsRetryable
    \/ BodyFailsFinally
    \/ BodyReturnsInner
    \/ InnerCompletes
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ MAX_RETRIES >= 0
    /\ outer \in OuterStates
    /\ inner \in InnerStates
    /\ attempts \in 0..MAX_RETRIES
    /\ joinInstalled \in BOOLEAN

RetryBoundSafety == attempts <= MAX_RETRIES

JoinAdmissionSafety ==
    joinInstalled => outer \in {"joining", "succeeded"}

TerminalStability ==
    outer = "succeeded" => /\ inner = "done" /\ joinInstalled

=============================================================================
