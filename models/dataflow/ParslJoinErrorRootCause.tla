--------------------------- MODULE ParslJoinErrorRootCause ---------------------------
EXTENDS Naturals, Sequences

(***************************************************************************
 * PropagatedException root-cause selection used by JoinError.
 *
 * The exception follows the first dependent exception recursively.  If a
 * propagated node has additional siblings, its displayed path annotates the
 * representative dependency with "(+ others)" while preserving the first
 * non-propagated exception as __cause__.
 ***************************************************************************)

VARIABLES outerCause, innerCause, path, root
vars == <<outerCause, innerCause, path, root>>

Init ==
    /\ outerCause = "propagated"
    /\ innerCause = "propagated"
    /\ path = <<>>
    /\ root = "unset"

ResolveOuter ==
    /\ outerCause = "propagated"
    /\ path' = <<"inner (+ others)">>
    /\ outerCause' = "resolved"
    /\ UNCHANGED <<innerCause, root>>

ResolveInner ==
    /\ outerCause = "resolved"
    /\ innerCause = "propagated"
    /\ path' = Append(path, "leaf")
    /\ innerCause' = "resolved"
    /\ UNCHANGED <<outerCause, root>>

SelectRoot ==
    /\ innerCause = "resolved"
    /\ root' = "leaf-exception"
    /\ UNCHANGED <<outerCause, innerCause, path>>

Next ==
    \/ ResolveOuter
    \/ ResolveInner
    \/ SelectRoot
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ outerCause \in {"propagated", "resolved"}
    /\ innerCause \in {"propagated", "resolved"}
    /\ path \in Seq({"inner (+ others)", "leaf"})
    /\ root \in {"unset", "leaf-exception"}

RootCauseSafety ==
    root = "leaf-exception" =>
        /\ path = <<"inner (+ others)", "leaf">>
        /\ innerCause = "resolved"

=============================================================================
