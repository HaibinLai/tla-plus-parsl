--------------------------- MODULE ParslJoinDuplicates ---------------------------
EXTENDS Naturals, Sequences, FiniteSets

(***************************************************************************
 * join_app list positions and duplicate Future references.
 *
 * The DFK stores a list of Future objects, not a set.  This model uses the
 * concrete shape [I1, I1, I2] to preserve duplicate references, callback
 * positions, aggregate ordering, and repeated failure entries.
 ***************************************************************************)

INNER == {"I1", "I2"}
POSITIONS == {1, 2, 3}
JoinAt == [p \in POSITIONS |-> IF p = 3 THEN "I2" ELSE "I1"]
InnerStates == {"unresolved", "succeeded", "failed"}
OuterStates == {"joining", "succeeded", "failed"}

VARIABLES innerState, innerResult, observedPositions, outerState,
          joinHandle, aggregateResult, failureCount
vars == <<innerState, innerResult, observedPositions, outerState,
           joinHandle, aggregateResult, failureCount>>

Init ==
    /\ innerState = [i \in INNER |-> "unresolved"]
    /\ innerResult = [i \in INNER |-> "none"]
    /\ observedPositions = {}
    /\ outerState = "joining"
    /\ joinHandle = TRUE
    /\ aggregateResult = <<>>
    /\ failureCount = 0

CompleteInner(i) ==
    /\ i \in INNER
    /\ innerState[i] = "unresolved"
    /\ innerState' = [innerState EXCEPT ![i] = "succeeded"]
    /\ innerResult' = [innerResult EXCEPT ![i] = i \o ":result"]
    /\ UNCHANGED <<observedPositions, outerState, joinHandle,
                    aggregateResult, failureCount>>

FailInner(i) ==
    /\ i \in INNER
    /\ innerState[i] = "unresolved"
    /\ innerState' = [innerState EXCEPT ![i] = "failed"]
    /\ innerResult' = [innerResult EXCEPT ![i] = i \o ":error"]
    /\ UNCHANGED <<observedPositions, outerState, joinHandle,
                    aggregateResult, failureCount>>

ObservePosition(p) ==
    /\ outerState = "joining"
    /\ p \in POSITIONS
    /\ p \notin observedPositions
    /\ innerState[JoinAt[p]] \in {"succeeded", "failed"}
    /\ observedPositions' = observedPositions \cup {p}
    /\ UNCHANGED <<innerState, innerResult, outerState, joinHandle,
                    aggregateResult, failureCount>>

DuplicateCallback(p) ==
    /\ p \in POSITIONS
    /\ p \in observedPositions
    /\ UNCHANGED vars

FinalizeJoin ==
    /\ outerState = "joining"
    /\ observedPositions = POSITIONS
    /\ \A p \in POSITIONS : innerState[JoinAt[p]] \in {"succeeded", "failed"}
    /\ LET failures == Cardinality({p \in POSITIONS :
              innerState[JoinAt[p]] = "failed"}) IN
        /\ outerState' = IF failures > 0 THEN "failed" ELSE "succeeded"
        /\ failureCount' = failures
        /\ aggregateResult' = IF failures = 0
              THEN <<innerResult["I1"], innerResult["I1"], innerResult["I2"]>>
              ELSE <<>>
    /\ joinHandle' = FALSE
    /\ UNCHANGED <<innerState, innerResult, observedPositions>>

Next ==
    \/ \E i \in INNER : CompleteInner(i) \/ FailInner(i)
    \/ \E p \in POSITIONS : ObservePosition(p) \/ DuplicateCallback(p)
    \/ FinalizeJoin
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ innerState \in [INNER -> InnerStates]
    /\ innerResult \in [INNER -> STRING]
    /\ observedPositions \subseteq POSITIONS
    /\ outerState \in OuterStates
    /\ joinHandle \in BOOLEAN
    /\ aggregateResult \in Seq(STRING)
    /\ failureCount \in 0..Cardinality(POSITIONS)

DuplicatePreservation ==
    outerState = "succeeded" =>
        aggregateResult = <<innerResult["I1"], innerResult["I1"], innerResult["I2"]>>

JoinFailureSafety ==
    outerState = "failed" =>
        /\ failureCount > 0
        /\ \E p \in POSITIONS : innerState[JoinAt[p]] = "failed"

FailureMultiplicitySafety ==
    outerState = "failed" =>
        failureCount = Cardinality({p \in POSITIONS :
              innerState[JoinAt[p]] = "failed"})

JoinHandleSafety ==
    /\ outerState = "joining" => joinHandle
    /\ outerState \in {"succeeded", "failed"} => ~joinHandle

CompletionSafety ==
    outerState = "succeeded" =>
        /\ observedPositions = POSITIONS
        /\ \A p \in POSITIONS : innerState[JoinAt[p]] = "succeeded"

=============================================================================
