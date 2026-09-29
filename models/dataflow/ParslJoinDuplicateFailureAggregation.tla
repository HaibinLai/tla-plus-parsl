--------------------------- MODULE ParslJoinDuplicateFailureAggregation ---------------------------
EXTENDS Naturals, Sequences

(***************************************************************************
 * Duplicate-preserving JoinError aggregation.
 *
 * A join list may contain the same Future more than once.  The callback scans
 * list positions, not a set of logical Future identities, so a failed Future
 * appearing twice contributes two entries to dependent_exceptions_tids.
 ***************************************************************************)

CONSTANT USE_FIXED

Inputs == <<"I1", "I2", "I1">>
OuterStates == {"joining", "failed"}

VARIABLES outerState, nextPosition, failureIds
vars == <<outerState, nextPosition, failureIds>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ outerState = "joining"
    /\ nextPosition = 1
    /\ failureIds = <<>>

ObservePosition ==
    /\ outerState = "joining"
    /\ nextPosition <= Len(Inputs)
    /\ nextPosition' = nextPosition + 1
    /\ UNCHANGED <<outerState, failureIds>>

Finalize ==
    /\ outerState = "joining"
    /\ nextPosition = Len(Inputs) + 1
    /\ outerState' = "failed"
    /\ failureIds' = IF USE_FIXED THEN <<"I1", "I1">> ELSE <<"I1">>
    /\ UNCHANGED nextPosition

Next ==
    \/ ObservePosition
    \/ Finalize
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ outerState \in OuterStates
    /\ nextPosition \in 1..(Len(Inputs) + 1)
    /\ failureIds \in Seq({"I1", "I2"})

DuplicateFailureMultiplicity ==
    outerState = "failed" => Len(failureIds) = 2

FailureOrderSafety ==
    outerState = "failed" => failureIds = <<"I1", "I1">>

=============================================================================
