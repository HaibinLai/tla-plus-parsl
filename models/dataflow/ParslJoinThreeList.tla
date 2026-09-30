-------------------------- MODULE ParslJoinThreeList --------------------------
EXTENDS Naturals, Sequences, FiniteSets

(***************************************************************************
 * Three-inner-Future join_app aggregation.
 *
 * The logical inner Future set is distinct from list positions: the same
 * Future may appear more than once, while the outer result must preserve all
 * positions and their order.  Completion callbacks can arrive in any order,
 * but finalization is allowed only after every distinct inner Future is done.
 ***************************************************************************)

INNER == {"I1", "I2", "I3"}
Inputs == <<"I3", "I1", "I2", "I1">>
POSITIONS == 1..Len(Inputs)
LogicalStates == {"pending", "succeeded", "failed"}
OuterStates == {"executing", "joining", "succeeded", "failed"}

VARIABLES outerState, innerState, observed, values, result, failureCount
vars == <<outerState, innerState, observed, values, result, failureCount>>

Init ==
    /\ outerState = "executing"
    /\ innerState = [i \in INNER |-> "pending"]
    /\ observed = {}
    /\ values = [i \in INNER |-> "unset"]
    /\ result = <<>>
    /\ failureCount = 0

ReturnList ==
    /\ outerState = "executing"
    /\ outerState' = "joining"
    /\ UNCHANGED <<innerState, observed, values, result, failureCount>>

Complete(i) ==
    /\ outerState = "joining"
    /\ i \in INNER
    /\ innerState[i] = "pending"
    /\ innerState' = [innerState EXCEPT ![i] = "succeeded"]
    /\ values' = [values EXCEPT ![i] = i \o ":value"]
    /\ UNCHANGED <<outerState, observed, result, failureCount>>

Fail(i) ==
    /\ outerState = "joining"
    /\ i \in INNER
    /\ innerState[i] = "pending"
    /\ innerState' = [innerState EXCEPT ![i] = "failed"]
    /\ UNCHANGED <<outerState, observed, values, result, failureCount>>

Observe(i) ==
    /\ outerState = "joining"
    /\ i \in INNER
    /\ innerState[i] # "pending"
    /\ i \notin observed
    /\ observed' = observed \cup {i}
    /\ UNCHANGED <<outerState, innerState, values, result, failureCount>>

Finalize ==
    /\ outerState = "joining"
    /\ observed = INNER
    /\ \A i \in INNER : innerState[i] # "pending"
    /\ IF \E i \in INNER : innerState[i] = "failed"
          THEN /\ outerState' = "failed"
               /\ result' = <<>>
               /\ failureCount' = Cardinality({i \in INNER : innerState[i] = "failed"})
          ELSE /\ outerState' = "succeeded"
               /\ result' = [p \in POSITIONS |-> values[Inputs[p]]]
               /\ UNCHANGED failureCount
    /\ UNCHANGED <<innerState, observed, values>>

Next ==
    \/ ReturnList
    \/ \E i \in INNER : Complete(i) \/ Fail(i) \/ Observe(i)
    \/ Finalize
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ outerState \in OuterStates
    /\ innerState \in [INNER -> LogicalStates]
    /\ observed \subseteq INNER
    /\ values \in [INNER -> (STRING \cup {"unset"})]
    /\ result \in Seq(STRING)
    /\ failureCount \in 0..Cardinality(INNER)

JoinGateSafety == outerState = "joining" => observed # INNER \/ result = <<>>
TerminalResultSafety == outerState = "succeeded" => Len(result) = Len(Inputs)
OrderedResultSafety ==
    outerState = "succeeded" =>
        result = [p \in POSITIONS |-> values[Inputs[p]]]
FailureSafety == outerState = "failed" => failureCount > 0

=============================================================================
