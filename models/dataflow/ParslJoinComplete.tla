--------------------------- MODULE ParslJoinComplete ---------------------------
EXTENDS Naturals, Sequences, FiniteSets

(***************************************************************************
 * A compact complete join_app abstraction.
 *
 * The outer app may return one Future, a list with duplicate Future
 * references, an empty list, or an invalid value.  Inner results include the
 * Python value None, and cancellation is terminal failure.  The current
 * branch loses duplicate list positions by treating the input as a set; the
 * fixed branch preserves the original sequence.
 ***************************************************************************)

CONSTANTS INNER, USE_FIXED

OuterStates == {"new", "executing", "joining", "succeeded", "failed"}
JoinModes == {"none", "single", "list", "empty", "invalid"}
InnerStates == {"unresolved", "succeeded", "failed", "cancelled"}
FailureCauses == {"none", "invalid", "inner"}
ResultValues == {"value-I1", "value-I2", "value-I3", "None", "unset"}

VARIABLES outerState, joinMode, joinInputs, observed, joinHandle,
          innerState, innerValue, outerResultKind, singleResult,
          listResult, failureCause

vars == <<outerState, joinMode, joinInputs, observed, joinHandle,
           innerState, innerValue, outerResultKind, singleResult,
           listResult, failureCause>>

JoinSet == {joinInputs[i] : i \in 1..Len(joinInputs)}
AllJoinDone ==
    \A i \in JoinSet : innerState[i] \in {"succeeded", "failed", "cancelled"}
ExpectedDuplicateList ==
    <<innerValue["I1"], innerValue["I2"], innerValue["I1"]>>

Init ==
    /\ INNER = {"I1", "I2", "I3"}
    /\ outerState = "new"
    /\ joinMode = "none"
    /\ joinInputs = <<>>
    /\ observed = {}
    /\ joinHandle = FALSE
    /\ innerState = [i \in INNER |-> "unresolved"]
    /\ innerValue = [i \in INNER |-> "unset"]
    /\ outerResultKind = "none"
    /\ singleResult = "unset"
    /\ listResult = <<>>
    /\ failureCause = "none"

StartOuter ==
    /\ outerState = "new"
    /\ outerState' = "executing"
    /\ UNCHANGED <<joinMode, joinInputs, observed, joinHandle,
                    innerState, innerValue, outerResultKind,
                    singleResult, listResult, failureCause>>

CompleteInner(i, v) ==
    /\ i \in INNER
    /\ innerState[i] = "unresolved"
    /\ v \in ResultValues \ {"unset"}
    /\ innerState' = [innerState EXCEPT ![i] = "succeeded"]
    /\ innerValue' = [innerValue EXCEPT ![i] = v]
    /\ UNCHANGED <<outerState, joinMode, joinInputs, observed, joinHandle,
                    outerResultKind, singleResult, listResult, failureCause>>

FailInner(i) ==
    /\ i \in INNER
    /\ innerState[i] = "unresolved"
    /\ innerState' = [innerState EXCEPT ![i] = "failed"]
    /\ UNCHANGED <<outerState, joinMode, joinInputs, observed, joinHandle,
                    innerState, innerValue, outerResultKind,
                    singleResult, listResult, failureCause>>

CancelInner(i) ==
    /\ i \in INNER
    /\ innerState[i] = "unresolved"
    /\ innerState' = [innerState EXCEPT ![i] = "cancelled"]
    /\ UNCHANGED <<outerState, joinMode, joinInputs, observed, joinHandle,
                    innerState, innerValue, outerResultKind,
                    singleResult, listResult, failureCause>>

ReturnSingle ==
    /\ outerState = "executing"
    /\ outerState' = "joining"
    /\ joinMode' = "single"
    /\ joinInputs' = <<"I1">>
    /\ observed' = {}
    /\ joinHandle' = TRUE
    /\ UNCHANGED <<innerState, innerValue, outerResultKind,
                    singleResult, listResult, failureCause>>

ReturnDuplicateList ==
    /\ outerState = "executing"
    /\ outerState' = "joining"
    /\ joinMode' = "list"
    /\ joinInputs' = <<"I1", "I2", "I1">>
    /\ observed' = {}
    /\ joinHandle' = TRUE
    /\ UNCHANGED <<innerState, innerValue, outerResultKind,
                    singleResult, listResult, failureCause>>

ReturnEmptyList ==
    /\ outerState = "executing"
    /\ outerState' = "joining"
    /\ joinMode' = "empty"
    /\ joinInputs' = <<>>
    /\ observed' = {}
    /\ joinHandle' = TRUE
    /\ UNCHANGED <<innerState, innerValue, outerResultKind,
                    singleResult, listResult, failureCause>>

ReturnInvalid ==
    /\ outerState = "executing"
    /\ outerState' = "failed"
    /\ joinMode' = "invalid"
    /\ failureCause' = "invalid"
    /\ joinHandle' = FALSE
    /\ UNCHANGED <<joinInputs, observed, innerState, innerValue,
                    outerResultKind, singleResult, listResult>>

ObserveInner(i) ==
    /\ outerState = "joining"
    /\ i \in JoinSet
    /\ innerState[i] \in {"succeeded", "failed", "cancelled"}
    /\ i \notin observed
    /\ observed' = observed \cup {i}
    /\ UNCHANGED <<outerState, joinMode, joinInputs, joinHandle,
                    innerState, innerValue, outerResultKind,
                    singleResult, listResult, failureCause>>

FinalizeJoin ==
    /\ outerState = "joining"
    /\ observed = JoinSet
    /\ AllJoinDone
    /\ LET hasFailure == \E i \in JoinSet :
              innerState[i] \in {"failed", "cancelled"}
       IN
        /\ outerState' = IF hasFailure THEN "failed" ELSE "succeeded"
        /\ failureCause' = IF hasFailure THEN "inner" ELSE "none"
        /\ outerResultKind' =
              IF hasFailure THEN "none"
              ELSE IF joinMode = "single" THEN "single"
              ELSE IF joinMode = "empty" THEN "empty" ELSE "list"
        /\ singleResult' = IF ~hasFailure /\ joinMode = "single"
                           THEN innerValue["I1"] ELSE singleResult
        /\ listResult' = IF ~hasFailure /\ joinMode = "list"
                         THEN IF USE_FIXED
                              THEN ExpectedDuplicateList
                              ELSE <<innerValue["I1"], innerValue["I2"]>>
                         ELSE listResult
    /\ joinHandle' = FALSE
    /\ UNCHANGED <<joinMode, joinInputs, observed, innerState, innerValue>>

Next ==
    \/ StartOuter
    \/ \E i \in INNER, v \in ResultValues : CompleteInner(i, v)
    \/ \E i \in INNER : FailInner(i) \/ CancelInner(i)
    \/ ReturnSingle
    \/ ReturnDuplicateList
    \/ ReturnEmptyList
    \/ ReturnInvalid
    \/ \E i \in INNER : ObserveInner(i)
    \/ FinalizeJoin
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ outerState \in OuterStates
    /\ joinMode \in JoinModes
    /\ joinInputs \in Seq(INNER)
    /\ observed \subseteq INNER
    /\ joinHandle \in BOOLEAN
    /\ innerState \in [INNER -> InnerStates]
    /\ innerValue \in [INNER -> ResultValues]
    /\ outerResultKind \in {"none", "single", "list", "empty"}
    /\ singleResult \in ResultValues
    /\ listResult \in Seq(ResultValues)
    /\ failureCause \in FailureCauses

JoinCompletionSafety ==
    /\ outerState = "succeeded" =>
          /\ observed = JoinSet
          /\ AllJoinDone
          /\ joinHandle = FALSE
    /\ outerState = "joining" => joinHandle = TRUE

JoinFailureSafety ==
    /\ outerState = "failed" /\ failureCause = "inner"
        => \E i \in JoinSet : innerState[i] \in {"failed", "cancelled"}
    /\ outerState = "failed" /\ failureCause = "invalid"
        => joinMode = "invalid" /\ joinHandle = FALSE

JoinResultSafety ==
    /\ outerResultKind = "single" => singleResult = innerValue["I1"]
    /\ outerResultKind = "list" => listResult = ExpectedDuplicateList
    /\ outerResultKind = "empty" => listResult = <<>>

JoinHandleSafety ==
    /\ outerState = "joining" => joinHandle
    /\ outerState \in {"succeeded", "failed"} => ~joinHandle

TerminalStateSafety ==
    /\ outerState = "succeeded" => outerResultKind \in {"single", "list", "empty"}
    /\ outerState = "failed" => failureCause \in {"invalid", "inner"}

=============================================================================
