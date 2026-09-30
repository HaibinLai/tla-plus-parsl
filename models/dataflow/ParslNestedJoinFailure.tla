--------------------------- MODULE ParslNestedJoinFailure ---------------------------
EXTENDS Naturals, Sequences, FiniteSets

(***************************************************************************
 * Nested join error payloads.
 *
 * A nested join aggregates failed leaf Futures in input order.  The outer
 * join observes the nested Future as one dependency, so its JoinError keeps
 * one nested dependency entry while the nested error retains all leaf causes.
 ***************************************************************************)

Leafs == {"L1", "L2", "L3"}
LeafOrder == <<"L1", "L2", "L3">>
LeafStates == {"pending", "succeeded", "failed"}
JoinStates == {"unresolved", "joining", "succeeded", "failed"}

VARIABLES leafState, nestedState, nestedObserved, nestedFailures,
          outerState, outerObserved, outerFailures
vars == <<leafState, nestedState, nestedObserved, nestedFailures,
           outerState, outerObserved, outerFailures>>

Init ==
    /\ leafState = [l \in Leafs |-> "pending"]
    /\ nestedState = "unresolved"
    /\ nestedObserved = {}
    /\ nestedFailures = <<>>
    /\ outerState = "unresolved"
    /\ outerObserved = {}
    /\ outerFailures = <<>>

StartNested ==
    /\ nestedState = "unresolved"
    /\ nestedState' = "joining"
    /\ UNCHANGED <<leafState, nestedObserved, nestedFailures,
                    outerState, outerObserved, outerFailures>>

StartOuter ==
    /\ outerState = "unresolved"
    /\ outerState' = "joining"
    /\ UNCHANGED <<leafState, nestedState, nestedObserved, nestedFailures,
                    outerObserved, outerFailures>>

CompleteLeaf(l, outcome) ==
    /\ l \in Leafs
    /\ leafState[l] = "pending"
    /\ outcome \in {"succeeded", "failed"}
    /\ leafState' = [leafState EXCEPT ![l] = outcome]
    /\ UNCHANGED <<nestedState, nestedObserved, nestedFailures,
                    outerState, outerObserved, outerFailures>>

ObserveNestedLeaf(l) ==
    /\ nestedState = "joining"
    /\ leafState[l] # "pending"
    /\ l \notin nestedObserved
    /\ nestedObserved' = nestedObserved \cup {l}
    /\ UNCHANGED <<leafState, nestedState, nestedFailures,
                    outerState, outerObserved, outerFailures>>

FinalizeNested ==
    /\ nestedState = "joining"
    /\ nestedObserved = Leafs
    /\ \A l \in Leafs : leafState[l] # "pending"
    /\ nestedFailures' =
          (IF leafState[LeafOrder[1]] = "failed" THEN <<LeafOrder[1]>> ELSE <<>>)
          \o (IF leafState[LeafOrder[2]] = "failed" THEN <<LeafOrder[2]>> ELSE <<>>)
          \o (IF leafState[LeafOrder[3]] = "failed" THEN <<LeafOrder[3]>> ELSE <<>>)
    /\ nestedState' = IF Len(nestedFailures') > 0 THEN "failed" ELSE "succeeded"
    /\ UNCHANGED <<leafState, nestedObserved, outerState, outerObserved, outerFailures>>

CompleteDirect ==
    /\ outerState = "joining"
    /\ "direct" \notin outerObserved
    /\ outerObserved' = outerObserved \cup {"direct"}
    /\ UNCHANGED <<leafState, nestedState, nestedObserved, nestedFailures,
                    outerState, outerFailures>>

ObserveNested ==
    /\ outerState = "joining"
    /\ nestedState \in {"succeeded", "failed"}
    /\ "nested" \notin outerObserved
    /\ outerObserved' = outerObserved \cup {"nested"}
    /\ UNCHANGED <<leafState, nestedState, nestedObserved, nestedFailures,
                    outerState, outerFailures>>

FinalizeOuter ==
    /\ outerState = "joining"
    /\ outerObserved = {"direct", "nested"}
    /\ nestedState \in {"succeeded", "failed"}
    /\ outerState' = IF nestedState = "failed" THEN "failed" ELSE "succeeded"
    /\ outerFailures' = IF nestedState = "failed" THEN <<"nested">> ELSE <<>>
    /\ UNCHANGED <<leafState, nestedState, nestedObserved, nestedFailures,
                    outerObserved>>

Next ==
    \/ StartNested
    \/ StartOuter
    \/ \E l \in Leafs, outcome \in {"succeeded", "failed"} : CompleteLeaf(l, outcome)
    \/ \E l \in Leafs : ObserveNestedLeaf(l)
    \/ FinalizeNested
    \/ CompleteDirect
    \/ ObserveNested
    \/ FinalizeOuter
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ leafState \in [Leafs -> LeafStates]
    /\ nestedState \in JoinStates
    /\ nestedObserved \subseteq Leafs
    /\ nestedFailures \in Seq(Leafs)
    /\ outerState \in JoinStates
    /\ outerObserved \subseteq {"direct", "nested"}
    /\ outerFailures \in Seq({"nested"})

NestedFailureShape ==
    nestedState = "failed" =>
        /\ Len(nestedFailures) > 0
        /\ \A i \in 1..Len(nestedFailures) : leafState[nestedFailures[i]] = "failed"
        /\ nestedFailures =
             (IF leafState[LeafOrder[1]] = "failed" THEN <<LeafOrder[1]>> ELSE <<>>)
             \o (IF leafState[LeafOrder[2]] = "failed" THEN <<LeafOrder[2]>> ELSE <<>>)
             \o (IF leafState[LeafOrder[3]] = "failed" THEN <<LeafOrder[3]>> ELSE <<>>)

OuterFailureShape ==
    outerState = "failed" =>
        /\ nestedState = "failed"
        /\ outerFailures = <<"nested">>

CompletionSafety ==
    /\ nestedState = "succeeded" => nestedFailures = <<>>
    /\ outerState = "succeeded" => nestedState = "succeeded"

=============================================================================
