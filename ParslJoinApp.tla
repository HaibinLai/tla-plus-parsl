--------------------------- MODULE ParslJoinApp ---------------------------
EXTENDS Naturals, Sequences, FiniteSets

(***************************************************************************
 * Bounded join_app semantics.
 *
 * The outer app first returns either one Future, a list of Futures, an empty
 * list, or an invalid value.  It then holds a join handle until every inner
 * Future is terminal.  A successful list join preserves the original input
 * order, while any inner failure produces an outer JoinError.  Inner Futures
 * own their retries; this model observes only their final states.
 ***************************************************************************)

CONSTANTS INNER

OuterStates == {"new", "executing", "joining", "succeeded", "failed"}
InnerStates == {"unresolved", "succeeded", "failed"}
JoinModes == {"none", "single", "list", "empty", "invalid"}
FailureCauses == {"none", "invalid", "inner"}
ResultKinds == {"none", "single", "list", "empty"}

VARIABLES outerState, joinMode, joinSet, observed, joinHandle,
          innerState, innerResult, outerResultKind, singleResult,
          listResult, failureCause

vars == <<outerState, joinMode, joinSet, observed, joinHandle,
           innerState, innerResult, outerResultKind, singleResult,
           listResult, failureCause>>

ExpectedListResult ==
    <<innerResult["I1"], innerResult["I2"], innerResult["I3"]>>

AllJoinDone ==
    \A i \in joinSet : innerState[i] \in {"succeeded", "failed"}

Init ==
    /\ INNER # {}
    /\ {"I1", "I2", "I3"} \subseteq INNER
    /\ outerState = "new"
    /\ joinMode = "none"
    /\ joinSet = {}
    /\ observed = {}
    /\ joinHandle = FALSE
    /\ innerState = [i \in INNER |-> "unresolved"]
    /\ innerResult = [i \in INNER |-> "none"]
    /\ outerResultKind = "none"
    /\ singleResult = "none"
    /\ listResult = <<>>
    /\ failureCause = "none"

StartOuter ==
    /\ outerState = "new"
    /\ outerState' = "executing"
    /\ UNCHANGED <<joinMode, joinSet, observed, joinHandle,
                    innerState, innerResult, outerResultKind,
                    singleResult, listResult, failureCause>>

CompleteInner(i) ==
    /\ innerState[i] = "unresolved"
    /\ innerState' = [innerState EXCEPT ![i] = "succeeded"]
    /\ innerResult' = [innerResult EXCEPT ![i] = i \o ":result"]
    /\ UNCHANGED <<outerState, joinMode, joinSet, observed, joinHandle,
                    outerResultKind, singleResult, listResult, failureCause>>

FailInner(i) ==
    /\ innerState[i] = "unresolved"
    /\ innerState' = [innerState EXCEPT ![i] = "failed"]
    /\ innerResult' = [innerResult EXCEPT ![i] = i \o ":error"]
    /\ UNCHANGED <<outerState, joinMode, joinSet, observed, joinHandle,
                    outerResultKind, singleResult, listResult, failureCause>>

ReturnSingle ==
    /\ outerState = "executing"
    /\ outerState' = "joining"
    /\ joinMode' = "single"
    /\ joinSet' = {"I1"}
    /\ observed' = {}
    /\ joinHandle' = TRUE
    /\ UNCHANGED <<innerState, innerResult, outerResultKind,
                    singleResult, listResult, failureCause>>

ReturnList ==
    /\ outerState = "executing"
    /\ outerState' = "joining"
    /\ joinMode' = "list"
    /\ joinSet' = INNER
    /\ observed' = {}
    /\ joinHandle' = TRUE
    /\ UNCHANGED <<innerState, innerResult, outerResultKind,
                    singleResult, listResult, failureCause>>

ReturnEmptyList ==
    /\ outerState = "executing"
    /\ outerState' = "joining"
    /\ joinMode' = "empty"
    /\ joinSet' = {}
    /\ observed' = {}
    /\ joinHandle' = TRUE
    /\ UNCHANGED <<innerState, innerResult, outerResultKind,
                    singleResult, listResult, failureCause>>

ReturnInvalid ==
    /\ outerState = "executing"
    /\ outerState' = "failed"
    /\ joinMode' = "invalid"
    /\ failureCause' = "invalid"
    /\ joinHandle' = FALSE
    /\ UNCHANGED <<joinSet, observed, innerState, innerResult,
                    outerResultKind, singleResult, listResult>>

ObserveInner(i) ==
    /\ outerState = "joining"
    /\ i \in joinSet
    /\ innerState[i] \in {"succeeded", "failed"}
    /\ i \notin observed
    /\ observed' = observed \cup {i}
    /\ UNCHANGED <<outerState, joinMode, joinSet, joinHandle,
                    innerState, innerResult, outerResultKind,
                    singleResult, listResult, failureCause>>

FinalizeJoin ==
    /\ outerState = "joining"
    /\ observed = joinSet
    /\ AllJoinDone
    /\ LET hasFailure == \E i \in joinSet : innerState[i] = "failed" IN
        /\ outerState' = IF hasFailure THEN "failed" ELSE "succeeded"
        /\ failureCause' = IF hasFailure THEN "inner" ELSE "none"
        /\ outerResultKind' =
              IF hasFailure THEN "none"
              ELSE IF joinMode = "single" THEN "single"
              ELSE IF joinMode = "empty" THEN "empty" ELSE "list"
        /\ singleResult' = IF ~hasFailure /\ joinMode = "single"
                           THEN innerResult["I1"] ELSE singleResult
        /\ listResult' = IF ~hasFailure /\ joinMode = "list"
                         THEN ExpectedListResult ELSE listResult
    /\ joinHandle' = FALSE
    /\ UNCHANGED <<joinMode, joinSet, observed, innerState, innerResult>>

Next ==
    \/ StartOuter
    \/ \E i \in INNER : CompleteInner(i) \/ FailInner(i)
    \/ ReturnSingle
    \/ ReturnList
    \/ ReturnEmptyList
    \/ ReturnInvalid
    \/ \E i \in INNER : ObserveInner(i)
    \/ FinalizeJoin
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ outerState \in OuterStates
    /\ joinMode \in JoinModes
    /\ joinSet \subseteq INNER
    /\ observed \subseteq joinSet
    /\ joinHandle \in BOOLEAN
    /\ innerState \in [INNER -> InnerStates]
    /\ innerResult \in [INNER -> STRING]
    /\ outerResultKind \in ResultKinds
    /\ singleResult \in STRING
    /\ listResult \in Seq(STRING)
    /\ failureCause \in FailureCauses

JoinCompletionSafety ==
    /\ outerState = "succeeded" =>
          /\ observed = joinSet
          /\ AllJoinDone
          /\ joinHandle = FALSE
    /\ outerState = "joining" => joinHandle = TRUE

JoinFailureSafety ==
    /\ outerState = "failed" /\ failureCause = "inner"
        => \E i \in joinSet : innerState[i] = "failed"
    /\ outerState = "failed" /\ failureCause = "invalid"
        => joinMode = "invalid" /\ joinHandle = FALSE

JoinResultSafety ==
    /\ outerResultKind = "single"
        => singleResult = innerResult["I1"]
    /\ outerResultKind = "list"
        => listResult = ExpectedListResult
    /\ outerResultKind = "empty"
        => listResult = <<>>

JoinHandleSafety ==
    /\ outerState = "joining" => joinHandle
    /\ outerState \in {"succeeded", "failed"} => ~joinHandle

TerminalStateSafety ==
    /\ outerState = "succeeded" => outerResultKind \in {"single", "list", "empty"}
    /\ outerState = "failed" => failureCause \in {"invalid", "inner"}

=============================================================================
