--------------------------- MODULE ParslJoinMixedList ---------------------------
EXTENDS Naturals, Sequences, FiniteSets

(***************************************************************************
 * A focused join_app list-shape model.
 *
 * DataFlowKernel accepts a list only when every element is a Future.  An empty
 * list is a valid immediately-completable join, while a mixed list such as
 * [Future, 7] or a non-empty value list such as [1, 2] fails with TypeError
 * before any inner callback is registered.
 ***************************************************************************)

CONSTANT LIST_SHAPE

Shapes == {"all_futures", "empty", "mixed", "values"}
OuterStates == {"executing", "joining", "succeeded", "failed"}
InnerStates == {"unresolved", "succeeded", "failed"}

VARIABLES outerState, innerState, joinHandle, callbacksRegistered,
          observed, output, failureCause, validated
vars == <<outerState, innerState, joinHandle, callbacksRegistered,
          observed, output, failureCause, validated>>

Init ==
    /\ LIST_SHAPE \in Shapes
    /\ outerState = "executing"
    /\ innerState = [i \in {"I1", "I2"} |-> "unresolved"]
    /\ joinHandle = FALSE
    /\ callbacksRegistered = FALSE
    /\ observed = {}
    /\ output = <<>>
    /\ failureCause = "none"
    /\ validated = FALSE

ReturnJoinable ==
    /\ LIST_SHAPE \in {"all_futures", "empty"}
    /\ outerState = "executing"
    /\ outerState' = "joining"
    /\ joinHandle' = TRUE
    /\ callbacksRegistered' = (LIST_SHAPE = "all_futures")
    /\ validated' = TRUE
    /\ UNCHANGED <<innerState, observed, output, failureCause>>

ReturnMixedList ==
    /\ LIST_SHAPE \in {"mixed", "values"}
    /\ outerState = "executing"
    /\ outerState' = "failed"
    /\ failureCause' = "invalid"
    /\ validated' = TRUE
    /\ UNCHANGED <<innerState, joinHandle, callbacksRegistered, observed, output>>

RegisterEmptyCompletion ==
    /\ LIST_SHAPE = "empty"
    /\ outerState = "joining"
    /\ ~callbacksRegistered
    /\ outerState' = "succeeded"
    /\ output' = <<>>
    /\ joinHandle' = FALSE
    /\ UNCHANGED <<innerState, callbacksRegistered, observed, failureCause, validated>>

CompleteInner(i) ==
    /\ LIST_SHAPE = "all_futures"
    /\ outerState = "joining"
    /\ callbacksRegistered
    /\ i \in {"I1", "I2"}
    /\ innerState[i] = "unresolved"
    /\ innerState' = [innerState EXCEPT ![i] = "succeeded"]
    /\ UNCHANGED <<outerState, joinHandle, callbacksRegistered, observed,
                    output, failureCause, validated>>

FailInner(i) ==
    /\ LIST_SHAPE = "all_futures"
    /\ outerState = "joining"
    /\ callbacksRegistered
    /\ i \in {"I1", "I2"}
    /\ innerState[i] = "unresolved"
    /\ innerState' = [innerState EXCEPT ![i] = "failed"]
    /\ UNCHANGED <<outerState, joinHandle, callbacksRegistered, observed,
                    output, failureCause, validated>>

Observe(i) ==
    /\ LIST_SHAPE = "all_futures"
    /\ outerState = "joining"
    /\ callbacksRegistered
    /\ innerState[i] \in {"succeeded", "failed"}
    /\ i \notin observed
    /\ observed' = observed \cup {i}
    /\ UNCHANGED <<outerState, innerState, joinHandle,
                    callbacksRegistered, output, failureCause, validated>>

Finalize ==
    /\ LIST_SHAPE = "all_futures"
    /\ outerState = "joining"
    /\ observed = {"I1", "I2"}
    /\ \A i \in {"I1", "I2"} : innerState[i] \in {"succeeded", "failed"}
    /\ IF \E i \in {"I1", "I2"} : innerState[i] = "failed"
          THEN /\ outerState' = "failed"
               /\ failureCause' = "inner"
               /\ output' = <<>>
          ELSE /\ outerState' = "succeeded"
               /\ failureCause' = "none"
               /\ output' = <<"I1:result", "I2:result">>
    /\ joinHandle' = FALSE
    /\ UNCHANGED <<innerState, callbacksRegistered, observed, validated>>

Next ==
    \/ ReturnJoinable
    \/ ReturnMixedList
    \/ RegisterEmptyCompletion
    \/ \E i \in {"I1", "I2"} : CompleteInner(i) \/ FailInner(i)
    \/ \E i \in {"I1", "I2"} : Observe(i)
    \/ Finalize
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ outerState \in OuterStates
    /\ innerState \in [{"I1", "I2"} -> InnerStates]
    /\ joinHandle \in BOOLEAN
    /\ callbacksRegistered \in BOOLEAN
    /\ observed \subseteq {"I1", "I2"}
    /\ output \in Seq(STRING)
    /\ failureCause \in {"none", "invalid", "inner"}
    /\ validated \in BOOLEAN

MixedListSafety ==
    (validated /\ LIST_SHAPE \in {"mixed", "values"}) =>
       /\ outerState = "failed"
       /\ failureCause = "invalid"
       /\ ~callbacksRegistered

JoinGateSafety ==
    outerState = "joining" => joinHandle

OrderedResultSafety ==
    output # <<>> => output = <<"I1:result", "I2:result">>

=============================================================================
