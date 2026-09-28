--------------------------- MODULE ParslJoinFailureAggregation ---------------------------
EXTENDS Naturals, Sequences, FiniteSets

(***************************************************************************
 * Multiple-failure aggregation in DataFlowKernel.handle_join_update.
 *
 * A list-valued join waits until every inner Future is terminal, then scans
 * the list in its original order. Every failed inner Future contributes one
 * entry to JoinError.dependent_exceptions_tids; successful results are not
 * included in that exception list.
 ***************************************************************************)

INNER == {"I1", "I2", "I3"}
InnerStates == {"pending", "succeeded", "failed"}
OuterStates == {"joining", "succeeded", "failed"}

VARIABLES innerState, joinInputs, observed, outerState, failureIds
vars == <<innerState, joinInputs, observed, outerState, failureIds>>

Init ==
    /\ innerState = [i \in INNER |-> "pending"]
    /\ joinInputs = <<"I1", "I2", "I3">>
    /\ observed = <<>>
    /\ outerState = "joining"
    /\ failureIds = <<>>

CompleteInner(i, outcome) ==
    /\ i \in INNER
    /\ innerState[i] = "pending"
    /\ outcome \in {"succeeded", "failed"}
    /\ innerState' = [innerState EXCEPT ![i] = outcome]
    /\ UNCHANGED <<joinInputs, observed, outerState, failureIds>>

ObserveInner(i) ==
    /\ i \in INNER
    /\ innerState[i] \in {"succeeded", "failed"}
    /\ ~\E j \in 1..Len(observed) : observed[j] = i
    /\ observed' = Append(observed, i)
    /\ UNCHANGED <<innerState, joinInputs, outerState, failureIds>>

Finalize ==
    /\ outerState = "joining"
    /\ Len(observed) = Len(joinInputs)
    /\ \A i \in INNER : \E j \in 1..Len(observed) : observed[j] = i
    /\ \A i \in INNER : innerState[i] # "pending"
    /\ failureIds' =
          (IF innerState["I1"] = "failed" THEN <<"I1">> ELSE <<>>)
          \o (IF innerState["I2"] = "failed" THEN <<"I2">> ELSE <<>>)
          \o (IF innerState["I3"] = "failed" THEN <<"I3">> ELSE <<>>)
    /\ outerState' = IF Len(failureIds') > 0 THEN "failed" ELSE "succeeded"
    /\ UNCHANGED <<innerState, joinInputs, observed>>

Next ==
    \/ \E i \in INNER, outcome \in {"succeeded", "failed"} : CompleteInner(i, outcome)
    \/ \E i \in INNER : ObserveInner(i)
    \/ Finalize
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ innerState \in [INNER -> InnerStates]
    /\ joinInputs \in Seq(INNER)
    /\ observed \in Seq(INNER)
    /\ outerState \in OuterStates
    /\ failureIds \in Seq(INNER)

WaitForAllSafety ==
    outerState = "joining" => failureIds = <<>>

FailureAggregationSafety ==
    outerState = "failed" =>
        /\ Len(failureIds) = Cardinality({i \in INNER : innerState[i] = "failed"})
        /\ \A i \in failureIds : innerState[i] = "failed"

=============================================================================
