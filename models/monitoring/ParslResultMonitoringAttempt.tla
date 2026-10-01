--------------------------- MODULE ParslResultMonitoringAttempt ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Stale result filtering at the monitoring database boundary.
 *
 * Attempt 0 is replaced by attempt 1 after a retry.  A late result from the
 * old attempt may arrive after the retry.  The Fixed branch records it as
 * stale and does not resolve the Future or persist terminal success; the
 * Current branch can publish that old result as a terminal database record.
 ***************************************************************************)

CONSTANT USE_FIXED

ResultStates == {"none", "delivered", "stale", "accepted"}
DbStates == {"empty", "succeeded"}

VARIABLES currentAttempt, attempt0, attempt1, resultAttempt, result,
          future, db, dbAttempt

vars == <<currentAttempt, attempt0, attempt1, resultAttempt, result,
           future, db, dbAttempt>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ currentAttempt = 0
    /\ attempt0 = "running"
    /\ attempt1 = "pending"
    /\ resultAttempt = 0
    /\ result = "none"
    /\ future = "unresolved"
    /\ db = "empty"
    /\ dbAttempt = 0

Retry ==
    /\ currentAttempt = 0
    /\ attempt0 = "running"
    /\ currentAttempt' = 1
    /\ attempt0' = "lost"
    /\ attempt1' = "running"
    /\ UNCHANGED <<resultAttempt, result, future, db, dbAttempt>>

PublishOldResult ==
    /\ currentAttempt = 1
    /\ attempt0 = "lost"
    /\ result = "none"
    /\ resultAttempt' = 0
    /\ result' = "delivered"
    /\ UNCHANGED <<currentAttempt, attempt0, attempt1, future, db, dbAttempt>>

PublishCurrentResult ==
    /\ currentAttempt = 1
    /\ attempt1 = "running"
    /\ result = "none"
    /\ resultAttempt' = 1
    /\ result' = "delivered"
    /\ UNCHANGED <<currentAttempt, attempt0, attempt1, future, db, dbAttempt>>

PersistOldFixed ==
    /\ USE_FIXED
    /\ result = "delivered"
    /\ resultAttempt # currentAttempt
    /\ result' = "stale"
    /\ UNCHANGED <<currentAttempt, attempt0, attempt1, resultAttempt,
                    future, db, dbAttempt>>

PersistOldCurrent ==
    /\ ~USE_FIXED
    /\ result = "delivered"
    /\ resultAttempt # currentAttempt
    /\ result' = "accepted"
    /\ future' = "resolved"
    /\ db' = "succeeded"
    /\ dbAttempt' = resultAttempt
    /\ UNCHANGED <<currentAttempt, attempt0, attempt1, resultAttempt>>

PersistCurrent ==
    /\ result = "delivered"
    /\ resultAttempt = currentAttempt
    /\ result' = "accepted"
    /\ future' = "resolved"
    /\ db' = "succeeded"
    /\ dbAttempt' = resultAttempt
    /\ UNCHANGED <<currentAttempt, attempt0, attempt1, resultAttempt>>

Next ==
    \/ Retry
    \/ PublishOldResult
    \/ PublishCurrentResult
    \/ PersistOldFixed
    \/ PersistOldCurrent
    \/ PersistCurrent
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ currentAttempt \in 0..1
    /\ attempt0 \in {"running", "lost"}
    /\ attempt1 \in {"pending", "running"}
    /\ resultAttempt \in 0..1
    /\ result \in ResultStates
    /\ future \in {"unresolved", "resolved"}
    /\ db \in DbStates
    /\ dbAttempt \in 0..1

DatabaseAttemptSafety == db = "succeeded" => dbAttempt = currentAttempt
FutureDatabaseConsistency == future = "resolved" => db = "succeeded" /\ dbAttempt = currentAttempt
StaleResultSafety == result = "stale" => db = "empty" /\ future = "unresolved"
TerminalResultStability == db = "succeeded" => future = "resolved"

=============================================================================
