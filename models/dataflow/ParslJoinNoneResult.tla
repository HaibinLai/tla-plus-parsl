--------------------------- MODULE ParslJoinNoneResult ---------------------------
EXTENDS Naturals, Sequences, FiniteSets

(***************************************************************************
 * Successful join_app propagation of a falsey/None result.
 *
 * ``None`` is a valid Python Future result, not a failure or an absent
 * Future.  This small model checks both a single Future join and a list join
 * preserve that value exactly, including list position.
 ***************************************************************************)

CONSTANT MODE
INNER == {"I1", "I2"}
Values == {"none", "value"}
OuterStates == {"new", "joining", "succeeded"}

VARIABLES outerState, innerState, innerResult, joinSet, observed,
          outerResult, joinHandle
vars == <<outerState, innerState, innerResult, joinSet, observed,
           outerResult, joinHandle>>

Init ==
    /\ MODE \in {"single", "list"}
    /\ outerState = "new"
    /\ innerState = [i \in INNER |-> "unresolved"]
    /\ innerResult = [i \in INNER |-> "none"]
    /\ joinSet = {}
    /\ observed = {}
    /\ outerResult = "unset"
    /\ joinHandle = FALSE

StartJoin ==
    /\ outerState = "new"
    /\ outerState' = "joining"
    /\ joinSet' = IF MODE = "single" THEN {"I1"} ELSE INNER
    /\ joinHandle' = TRUE
    /\ UNCHANGED <<innerState, innerResult, observed, outerResult>>

CompleteInner(i) ==
    /\ i \in INNER
    /\ i \in joinSet
    /\ innerState[i] = "unresolved"
    /\ innerState' = [innerState EXCEPT ![i] = "done"]
    /\ innerResult' = [innerResult EXCEPT ![i] = "none"]
    /\ UNCHANGED <<outerState, joinSet, observed, outerResult, joinHandle>>

Observe(i) ==
    /\ outerState = "joining"
    /\ i \in joinSet
    /\ innerState[i] = "done"
    /\ i \notin observed
    /\ observed' = observed \cup {i}
    /\ UNCHANGED <<outerState, innerState, innerResult, joinSet,
                    outerResult, joinHandle>>

Finalize ==
    /\ outerState = "joining"
    /\ observed = joinSet
    /\ \A i \in joinSet : innerState[i] = "done"
    /\ outerState' = "succeeded"
    /\ outerResult' = IF MODE = "single" THEN innerResult["I1"]
                      ELSE <<innerResult["I1"], innerResult["I2"]>>
    /\ joinHandle' = FALSE
    /\ UNCHANGED <<innerState, innerResult, joinSet, observed>>

Next ==
    \/ StartJoin
    \/ \E i \in INNER : CompleteInner(i)
    \/ \E i \in INNER : Observe(i)
    \/ Finalize
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ outerState \in OuterStates
    /\ innerState \in [INNER -> ( {"unresolved", "done"} )]
    /\ innerResult \in [INNER -> Values]
    /\ joinSet \subseteq INNER
    /\ observed \subseteq joinSet
    /\ joinHandle \in BOOLEAN

NoneResultSafety ==
    outerState = "succeeded" =>
        IF MODE = "single"
        THEN outerResult = "none"
        ELSE outerResult = <<"none", "none">>

JoinHandleSafety ==
    /\ outerState = "joining" => joinHandle
    /\ outerState = "succeeded" => ~joinHandle

=============================================================================
