--------------------------- MODULE ParslNestedJoin ---------------------------
EXTENDS Naturals, Sequences, FiniteSets

(***************************************************************************
 * Nested join_app refinement.
 *
 * The outer join observes one direct Future and one Future produced by a
 * nested join.  The nested join first observes its leaf Futures, publishes a
 * result or failure, and only then becomes observable by the outer join.
 ***************************************************************************)

Leafs == {"L1", "L2"}
OuterInners == {"direct", "nested"}
States == {"unresolved", "joining", "succeeded", "failed"}

VARIABLES outerState, outerObserved, outerHandle, outerResult,
          nestedState, nestedObserved, nestedHandle, nestedResult,
          leafState, leafResult, outerFailure, nestedFailure

vars == <<outerState, outerObserved, outerHandle, outerResult,
           nestedState, nestedObserved, nestedHandle, nestedResult,
           leafState, leafResult, outerFailure, nestedFailure>>

Init ==
    /\ outerState = "unresolved"
    /\ outerObserved = {}
    /\ outerHandle = FALSE
    /\ outerResult = <<>>
    /\ nestedState = "unresolved"
    /\ nestedObserved = {}
    /\ nestedHandle = FALSE
    /\ nestedResult = <<>>
    /\ leafState = [l \in Leafs |-> "unresolved"]
    /\ leafResult = [l \in Leafs |-> "none"]
    /\ outerFailure = FALSE
    /\ nestedFailure = FALSE

StartNestedJoin ==
    /\ nestedState = "unresolved"
    /\ nestedState' = "joining"
    /\ nestedHandle' = TRUE
    /\ UNCHANGED <<outerState, outerObserved, outerHandle, outerResult,
                    nestedObserved, nestedResult, leafState, leafResult,
                    outerFailure, nestedFailure>>

CompleteLeaf(l) ==
    /\ leafState[l] = "unresolved"
    /\ leafState' = [leafState EXCEPT ![l] = "succeeded"]
    /\ leafResult' = [leafResult EXCEPT ![l] = l \o ":result"]
    /\ UNCHANGED <<outerState, outerObserved, outerHandle, outerResult,
                    nestedState, nestedObserved, nestedHandle, nestedResult,
                    outerFailure, nestedFailure>>

FailLeaf(l) ==
    /\ leafState[l] = "unresolved"
    /\ leafState' = [leafState EXCEPT ![l] = "failed"]
    /\ leafResult' = [leafResult EXCEPT ![l] = l \o ":error"]
    /\ UNCHANGED <<outerState, outerObserved, outerHandle, outerResult,
                    nestedState, nestedObserved, nestedHandle, nestedResult,
                    outerFailure, nestedFailure>>

ObserveNestedLeaf(l) ==
    /\ nestedState = "joining"
    /\ leafState[l] \in {"succeeded", "failed"}
    /\ l \notin nestedObserved
    /\ nestedObserved' = nestedObserved \cup {l}
    /\ UNCHANGED <<outerState, outerObserved, outerHandle, outerResult,
                    nestedState, nestedHandle, nestedResult,
                    leafState, leafResult, outerFailure, nestedFailure>>

FinalizeNested ==
    /\ nestedState = "joining"
    /\ nestedObserved = Leafs
    /\ \A l \in Leafs : leafState[l] \in {"succeeded", "failed"}
    /\ nestedFailure' = \E l \in Leafs : leafState[l] = "failed"
    /\ nestedState' = IF nestedFailure' THEN "failed" ELSE "succeeded"
    /\ nestedResult' = IF nestedFailure'
                       THEN <<>>
                       ELSE <<leafResult["L1"], leafResult["L2"]>>
    /\ nestedHandle' = FALSE
    /\ UNCHANGED <<outerState, outerObserved, outerHandle, outerResult,
                    nestedObserved, leafState, leafResult, outerFailure>>

StartOuterJoin ==
    /\ outerState = "unresolved"
    /\ outerState' = "joining"
    /\ outerHandle' = TRUE
    /\ UNCHANGED <<outerObserved, outerResult, nestedState, nestedObserved,
                    nestedHandle, nestedResult, leafState, leafResult,
                    outerFailure, nestedFailure>>

CompleteDirect ==
    /\ outerState = "joining"
    /\ "direct" \notin outerObserved
    /\ outerObserved' = outerObserved \cup {"direct"}
    /\ UNCHANGED <<outerState, outerHandle, outerResult,
                    nestedState, nestedObserved, nestedHandle, nestedResult,
                    leafState, leafResult, outerFailure, nestedFailure>>

ObserveNestedResult ==
    /\ outerState = "joining"
    /\ nestedState \in {"succeeded", "failed"}
    /\ "nested" \notin outerObserved
    /\ outerObserved' = outerObserved \cup {"nested"}
    /\ UNCHANGED <<outerState, outerHandle, outerResult,
                    nestedState, nestedObserved, nestedHandle, nestedResult,
                    leafState, leafResult, outerFailure, nestedFailure>>

FinalizeOuter ==
    /\ outerState = "joining"
    /\ outerObserved = OuterInners
    /\ nestedState \in {"succeeded", "failed"}
    /\ outerFailure' = nestedFailure
    /\ outerState' = IF outerFailure' THEN "failed" ELSE "succeeded"
    /\ outerResult' = IF outerFailure'
                      THEN <<>>
                      ELSE <<"direct:result", nestedResult>>
    /\ outerHandle' = FALSE
    /\ UNCHANGED <<outerObserved, nestedState, nestedObserved, nestedHandle, nestedResult,
                    leafState, leafResult, nestedFailure>>

Next ==
    \/ StartNestedJoin
    \/ \E l \in Leafs : CompleteLeaf(l) \/ FailLeaf(l)
    \/ \E l \in Leafs : ObserveNestedLeaf(l)
    \/ FinalizeNested
    \/ StartOuterJoin
    \/ CompleteDirect
    \/ ObserveNestedResult
    \/ FinalizeOuter
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ outerState \in States
    /\ outerObserved \subseteq OuterInners
    /\ outerHandle \in BOOLEAN
    /\ nestedState \in States
    /\ nestedObserved \subseteq Leafs
    /\ nestedHandle \in BOOLEAN
    /\ nestedResult \in Seq(STRING)
    /\ leafState \in [Leafs -> States \ {"joining"}]
    /\ leafResult \in [Leafs -> STRING]
    /\ outerFailure \in BOOLEAN
    /\ nestedFailure \in BOOLEAN

NestedCompletionSafety ==
    /\ nestedState = "succeeded" =>
          /\ nestedObserved = Leafs
          /\ ~nestedHandle
          /\ nestedResult = <<leafResult["L1"], leafResult["L2"]>>
    /\ nestedState = "joining" => nestedHandle

OuterCompletionSafety ==
    /\ outerState = "succeeded" =>
          /\ outerObserved = OuterInners
          /\ nestedState = "succeeded"
          /\ ~outerHandle
    /\ outerState = "joining" => outerHandle

NestedFailurePropagation ==
    /\ nestedState = "failed" => nestedFailure
    /\ outerState = "failed" =>
          /\ outerFailure
          /\ nestedState = "failed"
          /\ ~outerHandle

NoEarlyOuterCompletion ==
    outerState = "succeeded" => nestedState = "succeeded"

=============================================================================
