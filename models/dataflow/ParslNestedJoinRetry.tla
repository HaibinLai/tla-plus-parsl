----------------------- MODULE ParslNestedJoinRetry -----------------------
EXTENDS Naturals, FiniteSets

(***************************************************************************
 * Nested join with leaf retry and late results.
 *
 * Two leaf Futures feed an inner join; that inner Future feeds an outer join.
 * A failed first attempt may retry, and an old result can arrive after the
 * retry has started.  The fixed branch ignores that stale result so neither
 * join can report success while a leaf is failed or unresolved.
 ***************************************************************************)

CONSTANT USE_FIXED
Leaves == {"L1", "L2"}

VARIABLES leaf, future, attempt, staleDelivered, inner, outer
vars == <<leaf, future, attempt, staleDelivered, inner, outer>>

Init ==
    /\ leaf = [l \in Leaves |-> "pending"]
    /\ future = [l \in Leaves |-> "unresolved"]
    /\ attempt = [l \in Leaves |-> 0]
    /\ staleDelivered = FALSE
    /\ inner = "waiting"
    /\ outer = "waiting"

Start(l) ==
    /\ l \in Leaves
    /\ leaf[l] = "pending"
    /\ leaf' = [leaf EXCEPT ![l] = "running"]
    /\ UNCHANGED <<future, attempt, staleDelivered, inner, outer>>

Complete(l) ==
    /\ l \in Leaves
    /\ leaf[l] = "running"
    /\ leaf' = [leaf EXCEPT ![l] = "succeeded"]
    /\ future' = [future EXCEPT ![l] = "resolved"]
    /\ UNCHANGED <<attempt, staleDelivered, inner, outer>>

Retry(l) ==
    /\ l \in Leaves
    /\ leaf[l] = "running"
    /\ attempt[l] = 0
    /\ attempt' = [attempt EXCEPT ![l] = 1]
    /\ leaf' = [leaf EXCEPT ![l] = "pending"]
    /\ UNCHANGED <<future, staleDelivered, inner, outer>>

Fail(l) ==
    /\ l \in Leaves
    /\ leaf[l] = "running"
    /\ attempt[l] = 1
    /\ leaf' = [leaf EXCEPT ![l] = "failed"]
    /\ future' = [future EXCEPT ![l] = "rejected"]
    /\ UNCHANGED <<attempt, staleDelivered, inner, outer>>

LateResult(l) ==
    /\ l \in Leaves
    /\ attempt[l] = 1
    /\ leaf[l] \in {"pending", "running", "failed"}
    /\ staleDelivered' = TRUE
    /\ IF USE_FIXED
          THEN future' = future
          ELSE future' = [future EXCEPT ![l] = "resolved"]
    /\ UNCHANGED <<leaf, attempt, inner, outer>>

ResolveInner ==
    /\ inner = "waiting"
    /\ IF \A l \in Leaves : future[l] = "resolved"
          THEN inner' = "succeeded"
          ELSE IF \E l \in Leaves : future[l] = "rejected"
               THEN inner' = "failed"
               ELSE inner' = inner
    /\ UNCHANGED <<leaf, future, attempt, staleDelivered, outer>>

ResolveOuter ==
    /\ outer = "waiting"
    /\ IF inner = "succeeded"
          THEN outer' = "succeeded"
          ELSE IF inner = "failed"
               THEN outer' = "failed"
               ELSE outer' = outer
    /\ UNCHANGED <<leaf, future, attempt, staleDelivered, inner>>

Next ==
    \/ \E l \in Leaves : Start(l) \/ Complete(l) \/ Retry(l) \/ Fail(l)
    \/ \E l \in Leaves : LateResult(l)
    \/ ResolveInner
    \/ ResolveOuter
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ leaf \in [Leaves -> {"pending", "running", "succeeded", "failed"}]
    /\ future \in [Leaves -> {"unresolved", "resolved", "rejected"}]
    /\ attempt \in [Leaves -> 0..1]
    /\ staleDelivered \in BOOLEAN
    /\ inner \in {"waiting", "succeeded", "failed"}
    /\ outer \in {"waiting", "succeeded", "failed"}

RetryBoundSafety == \A l \in Leaves : attempt[l] <= 1

LeafFutureSafety ==
    \A l \in Leaves :
        /\ future[l] = "resolved" => leaf[l] = "succeeded" \/ ~staleDelivered
        /\ future[l] = "rejected" => leaf[l] = "failed"

NestedSuccessSafety ==
    outer = "succeeded" =>
        /\ inner = "succeeded"
        /\ \A l \in Leaves : leaf[l] = "succeeded"

=============================================================================
CONSTANT USE_FIXED = TRUE

SPECIFICATION Spec

INVARIANTS
    TypeOK
    RetryBoundSafety
    LeafFutureSafety
    NestedSuccessSafety
