-------------------- MODULE ParslJoinFailureOrder --------------------
EXTENDS Naturals, Sequences

(***************************************************************************
 * Ordered join result construction.
 *
 * Inner Futures may complete in either order, but join_app returns values in
 * the original join-list positions.  This keeps duplicate/positional data
 * stable and separates callback scheduling from result shape.
 *************************************************************************** *)

Inputs == 1..2
Values == {"one", "two"}

VARIABLES done, completionOrder, result
vars == <<done, completionOrder, result>>

Init ==
    /\ done = {}
    /\ completionOrder = <<>>
    /\ result = <<>>

Complete(i) ==
    /\ i \in Inputs
    /\ i \notin done
    /\ done' = done \cup {i}
    /\ completionOrder' = Append(completionOrder, i)
    /\ UNCHANGED result

Finalize ==
    /\ done = Inputs
    /\ result = <<>>
    /\ result' = <<"one", "two">>
    /\ UNCHANGED <<done, completionOrder>>

Next ==
    \/ \E i \in Inputs : Complete(i)
    \/ Finalize
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ done \subseteq Inputs
    /\ completionOrder \in Seq(Inputs)
    /\ result \in Seq(Values)

OrderSafety == result = <<"one", "two">>
                 \/ result = <<>>

=============================================================================
