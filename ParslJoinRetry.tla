--------------------------- MODULE ParslJoinRetry ---------------------------
EXTENDS Naturals, Sequences, FiniteSets

(***************************************************************************
 * Inner retry refinement for join_app.
 *
 * Logical inner Futures are separate from their physical attempts.  A failed
 * non-final attempt leaves the inner Future unresolved, so the outer join
 * cannot fail early.  Only the final inner outcome is observed and included
 * in the ordered aggregate result.
 ***************************************************************************)

CONSTANTS INNER, MAX_RETRIES

OuterStates == {"new", "executing", "joining", "succeeded", "failed"}
InnerStates == {"unresolved", "succeeded", "failed"}
AttemptStates == {"absent", "running", "failed", "succeeded"}

VARIABLES outerState, joinSet, observed, joinHandle,
          innerState, currentAttempt, attemptState, innerResult,
          listResult, failureCause

vars == <<outerState, joinSet, observed, joinHandle,
           innerState, currentAttempt, attemptState, innerResult,
           listResult, failureCause>>

AllJoinDone ==
    \A i \in joinSet : innerState[i] \in {"succeeded", "failed"}

ExpectedListResult == <<innerResult["I1"], innerResult["I2"]>>

Init ==
    /\ INNER = {"I1", "I2"}
    /\ MAX_RETRIES >= 1
    /\ outerState = "new"
    /\ joinSet = {}
    /\ observed = {}
    /\ joinHandle = FALSE
    /\ innerState = [i \in INNER |-> "unresolved"]
    /\ currentAttempt = [i \in INNER |-> 0]
    /\ attemptState = [i \in INNER |->
          [k \in 0..MAX_RETRIES |-> "absent"]]
    /\ innerResult = [i \in INNER |-> "none"]
    /\ listResult = <<>>
    /\ failureCause = "none"

StartOuter ==
    /\ outerState = "new"
    /\ outerState' = "executing"
    /\ UNCHANGED <<joinSet, observed, joinHandle, innerState,
                    currentAttempt, attemptState, innerResult,
                    listResult, failureCause>>

StartAttempt(i) ==
    /\ innerState[i] = "unresolved"
    /\ attemptState[i][currentAttempt[i]] = "absent"
    /\ attemptState' = [attemptState EXCEPT
          ![i][currentAttempt[i]] = "running"]
    /\ UNCHANGED <<outerState, joinSet, observed, joinHandle,
                    innerState, currentAttempt, innerResult,
                    listResult, failureCause>>

FailAttempt(i) ==
    /\ innerState[i] = "unresolved"
    /\ attemptState[i][currentAttempt[i]] = "running"
    /\ attemptState' = [attemptState EXCEPT
          ![i][currentAttempt[i]] = "failed"]
    /\ innerState' = [innerState EXCEPT ![i] =
          IF currentAttempt[i] = MAX_RETRIES THEN "failed" ELSE @]
    /\ innerResult' = [innerResult EXCEPT ![i] =
          IF currentAttempt[i] = MAX_RETRIES THEN i \o ":error" ELSE @]
    /\ UNCHANGED <<outerState, joinSet, observed, joinHandle,
                    currentAttempt, listResult, failureCause>>

RetryAttempt(i) ==
    /\ innerState[i] = "unresolved"
    /\ currentAttempt[i] < MAX_RETRIES
    /\ attemptState[i][currentAttempt[i]] = "failed"
    /\ currentAttempt' = [currentAttempt EXCEPT ![i] = @ + 1]
    /\ UNCHANGED <<outerState, joinSet, observed, joinHandle,
                    innerState, attemptState, innerResult,
                    listResult, failureCause>>

CompleteAttempt(i) ==
    /\ innerState[i] = "unresolved"
    /\ attemptState[i][currentAttempt[i]] = "running"
    /\ attemptState' = [attemptState EXCEPT
          ![i][currentAttempt[i]] = "succeeded"]
    /\ innerState' = [innerState EXCEPT ![i] = "succeeded"]
    /\ innerResult' = [innerResult EXCEPT ![i] = i \o ":result"]
    /\ UNCHANGED <<outerState, joinSet, observed, joinHandle,
                    currentAttempt, listResult, failureCause>>

ReturnList ==
    /\ outerState = "executing"
    /\ outerState' = "joining"
    /\ joinSet' = INNER
    /\ observed' = {}
    /\ joinHandle' = TRUE
    /\ UNCHANGED <<innerState, currentAttempt, attemptState,
                    innerResult, listResult, failureCause>>

ObserveInner(i) ==
    /\ outerState = "joining"
    /\ i \in joinSet
    /\ innerState[i] \in {"succeeded", "failed"}
    /\ i \notin observed
    /\ observed' = observed \cup {i}
    /\ UNCHANGED <<outerState, joinSet, joinHandle, innerState,
                    currentAttempt, attemptState, innerResult,
                    listResult, failureCause>>

FinalizeJoin ==
    /\ outerState = "joining"
    /\ observed = joinSet
    /\ AllJoinDone
    /\ LET hasFailure == \E i \in joinSet : innerState[i] = "failed" IN
        /\ outerState' = IF hasFailure THEN "failed" ELSE "succeeded"
        /\ failureCause' = IF hasFailure THEN "inner" ELSE "none"
        /\ listResult' = IF ~hasFailure THEN ExpectedListResult ELSE listResult
    /\ joinHandle' = FALSE
    /\ UNCHANGED <<joinSet, observed, innerState, currentAttempt,
                    attemptState, innerResult>>

Next ==
    \/ StartOuter
    \/ \E i \in INNER : StartAttempt(i)
    \/ \E i \in INNER : FailAttempt(i) \/ RetryAttempt(i) \/ CompleteAttempt(i)
    \/ ReturnList
    \/ \E i \in INNER : ObserveInner(i)
    \/ FinalizeJoin
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ outerState \in OuterStates
    /\ joinSet \subseteq INNER
    /\ observed \subseteq joinSet
    /\ joinHandle \in BOOLEAN
    /\ innerState \in [INNER -> InnerStates]
    /\ currentAttempt \in [INNER -> 0..MAX_RETRIES]
    /\ attemptState \in [INNER -> [0..MAX_RETRIES -> AttemptStates]]
    /\ innerResult \in [INNER -> STRING]
    /\ listResult \in Seq(STRING)
    /\ failureCause \in {"none", "inner"}

RetryIsolationSafety ==
    \A i \in INNER :
        /\ (\A k \in 0..MAX_RETRIES :
              attemptState[i][k] = "failed" /\ currentAttempt[i] = k
              => innerState[i] = "unresolved" \/ k = MAX_RETRIES)
        /\ innerState[i] = "succeeded" =>
              attemptState[i][currentAttempt[i]] = "succeeded"
        /\ innerState[i] = "failed" =>
              currentAttempt[i] = MAX_RETRIES

JoinCompletionSafety ==
    /\ outerState = "joining" => joinHandle
    /\ outerState = "succeeded" =>
          /\ observed = joinSet
          /\ AllJoinDone
          /\ listResult = ExpectedListResult
          /\ ~joinHandle

JoinFailureSafety ==
    outerState = "failed" =>
        /\ failureCause = "inner"
        /\ \E i \in joinSet : innerState[i] = "failed"
        /\ ~joinHandle

NoEarlyJoinFailure ==
    outerState = "failed" =>
        \E i \in joinSet : innerState[i] = "failed"

=============================================================================
