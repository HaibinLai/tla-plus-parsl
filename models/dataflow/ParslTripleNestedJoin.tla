--------------------------- MODULE ParslTripleNestedJoin ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Three-level nested join_app dependency propagation.
 *
 * Leaves A and B feed inner join J1.  J1 and leaf C feed outer join J2, and
 * J2 feeds the root join.  The current branch allows J2 to evaluate when only
 * one of its inputs is terminal; the fixed branch requires both inputs.
 ***************************************************************************)

CONSTANT USE_FIXED

LeafStates == {"pending", "running", "succeeded", "failed"}
JoinStates == {"unresolved", "succeeded", "failed"}
RootStates == {"pending", "succeeded", "failed"}

VARIABLES leaf, j1, j2, root, result
vars == <<leaf, j1, j2, root, result>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ leaf = [x \in {"A", "B", "C"} |-> "pending"]
    /\ j1 = "unresolved"
    /\ j2 = "unresolved"
    /\ root = "pending"
    /\ result = "none"

StartLeaf(x) ==
    /\ x \in {"A", "B", "C"}
    /\ leaf[x] = "pending"
    /\ leaf' = [leaf EXCEPT ![x] = "running"]
    /\ UNCHANGED <<j1, j2, root, result>>

CompleteLeaf(x) ==
    /\ x \in {"A", "B", "C"}
    /\ leaf[x] = "running"
    /\ leaf' = [leaf EXCEPT ![x] = "succeeded"]
    /\ UNCHANGED <<j1, j2, root, result>>

FailLeaf(x) ==
    /\ x \in {"A", "B", "C"}
    /\ leaf[x] = "running"
    /\ leaf' = [leaf EXCEPT ![x] = "failed"]
    /\ UNCHANGED <<j1, j2, root, result>>

EvaluateJ1 ==
    /\ j1 = "unresolved"
    /\ leaf["A"] \in LeafStates \ {"pending", "running"}
    /\ leaf["B"] \in LeafStates \ {"pending", "running"}
    /\ j1' = IF leaf["A"] = "failed" \/ leaf["B"] = "failed"
             THEN "failed" ELSE "succeeded"
    /\ UNCHANGED <<leaf, j2, root, result>>

EvaluateJ2 ==
    /\ j2 = "unresolved"
    /\ (IF USE_FIXED
       THEN /\ j1 \in JoinStates \ {"unresolved"}
            /\ leaf["C"] \in LeafStates \ {"pending", "running"}
       ELSE /\ j1 \in JoinStates \ {"unresolved"}
            \/ leaf["C"] \in LeafStates \ {"pending", "running"})
    /\ j2' = IF j1 = "failed" \/ leaf["C"] = "failed"
             THEN "failed" ELSE "succeeded"
    /\ UNCHANGED <<leaf, j1, root, result>>

FinalizeRoot ==
    /\ root = "pending"
    /\ j2 \in {"succeeded", "failed"}
    /\ root' = IF j2 = "failed" THEN "failed" ELSE "succeeded"
    /\ result' = IF j2 = "failed" THEN "join-error" ELSE "root-value"
    /\ UNCHANGED <<leaf, j1, j2>>

Next ==
    \/ \E x \in {"A", "B", "C"} : StartLeaf(x) \/ CompleteLeaf(x) \/ FailLeaf(x)
    \/ EvaluateJ1
    \/ EvaluateJ2
    \/ FinalizeRoot
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ leaf \in [{"A", "B", "C"} -> LeafStates]
    /\ j1 \in JoinStates
    /\ j2 \in JoinStates
    /\ root \in RootStates
    /\ result \in {"none", "root-value", "join-error"}

J1DependencySafety ==
    j1 # "unresolved" =>
        leaf["A"] \notin {"pending", "running"}
        /\ leaf["B"] \notin {"pending", "running"}

J2DependencySafety ==
    j2 # "unresolved" =>
        j1 # "unresolved" /\ leaf["C"] \notin {"pending", "running"}

RootDependencySafety ==
    root # "pending" => j2 # "unresolved"

ResultConsistency ==
    (root = "succeeded" => result = "root-value")
    /\ (root = "failed" => result = "join-error")

=============================================================================
