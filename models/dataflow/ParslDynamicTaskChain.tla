--------------------------- MODULE ParslDynamicTaskChain ---------------------------
EXTENDS Naturals, FiniteSets

(***************************************************************************
 * A bounded two-level dynamic DAG.
 *
 * The parent creates C1 and C2 after its Future resolves.  C1 then creates G
 * after C1 resolves; G depends on both the parent and C1.  Logical Futures
 * are kept separate from physical retry counters for every created node.
 ***************************************************************************)

CONSTANT MAX_RETRIES

Nodes == {"parent", "C1", "C2", "G"}
Children == {"C1", "C2"}
NodeStates == {"pending", "blocked", "running", "succeeded", "failed", "absent"}
FutureStates == {"unresolved", "resolved", "rejected"}

Deps(n) ==
    IF n = "C1" THEN {"parent"}
    ELSE IF n = "C2" THEN {"parent"}
    ELSE IF n = "G" THEN {"parent", "C1"}
    ELSE {}

VARIABLES state, future, attempts, created
vars == <<state, future, attempts, created>>

Init ==
    /\ MAX_RETRIES >= 0
    /\ state = [n \in Nodes |-> IF n = "parent" THEN "pending" ELSE "absent"]
    /\ future = [n \in Nodes |-> "unresolved"]
    /\ attempts = [n \in Nodes |-> 0]
    /\ created = [n \in Nodes |-> n = "parent"]

Start(n) ==
    /\ n \in Nodes
    /\ state[n] = "pending"
    /\ state' = [state EXCEPT ![n] = "running"]
    /\ UNCHANGED <<future, attempts, created>>

Complete(n) ==
    /\ n \in Nodes
    /\ state[n] = "running"
    /\ state' = [state EXCEPT ![n] = "succeeded"]
    /\ future' = [future EXCEPT ![n] = "resolved"]
    /\ UNCHANGED <<attempts, created>>

Retry(n) ==
    /\ n \in Nodes
    /\ state[n] = "running"
    /\ future[n] = "unresolved"
    /\ attempts[n] < MAX_RETRIES
    /\ attempts' = [attempts EXCEPT ![n] = @ + 1]
    /\ state' = [state EXCEPT ![n] = "pending"]
    /\ UNCHANGED <<future, created>>

Fail(n) ==
    /\ n \in Nodes
    /\ state[n] = "running"
    /\ future[n] = "unresolved"
    /\ attempts[n] = MAX_RETRIES
    /\ state' = [state EXCEPT ![n] = "failed"]
    /\ future' = [future EXCEPT ![n] = "rejected"]
    /\ UNCHANGED <<attempts, created>>

Ready(n) ==
    /\ n \in Nodes
    /\ created[n]
    /\ \A d \in Deps(n) : future[d] = "resolved"

CreateChildren ==
    /\ state["parent"] = "succeeded"
    /\ future["parent"] = "resolved"
    /\ ~created["C1"]
    /\ ~created["C2"]
    /\ state' = [state EXCEPT !["C1"] = "blocked", !["C2"] = "blocked"]
    /\ created' = [created EXCEPT !["C1"] = TRUE, !["C2"] = TRUE]
    /\ UNCHANGED <<future, attempts>>

Release(n) ==
    /\ n \in Nodes
    /\ created[n]
    /\ state[n] = "blocked"
    /\ Ready(n)
    /\ state' = [state EXCEPT ![n] = "pending"]
    /\ UNCHANGED <<future, attempts, created>>

CreateGrandchild ==
    /\ state["C1"] = "succeeded"
    /\ future["C1"] = "resolved"
    /\ ~created["G"]
    /\ state' = [state EXCEPT !["G"] = "blocked"]
    /\ created' = [created EXCEPT !["G"] = TRUE]
    /\ UNCHANGED <<future, attempts>>

Next ==
    \/ \E n \in Nodes : Start(n) \/ Complete(n) \/ Retry(n) \/ Fail(n)
    \/ CreateChildren
    \/ CreateGrandchild
    \/ \E n \in Nodes : Release(n)
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in [Nodes -> NodeStates]
    /\ future \in [Nodes -> FutureStates]
    /\ attempts \in [Nodes -> 0..MAX_RETRIES]
    /\ created \in [Nodes -> BOOLEAN]

CreationSafety ==
    /\ created["C1"] => state["parent"] = "succeeded"
    /\ created["C2"] => state["parent"] = "succeeded"
    /\ created["G"] => state["C1"] = "succeeded"

DependencySafety ==
    \A n \in Nodes : created[n] /\ state[n] \in {"pending", "running", "succeeded"}
        => Ready(n)

FutureConsistency ==
    \A n \in Nodes :
        /\ future[n] = "resolved" => state[n] = "succeeded"
        /\ future[n] = "rejected" => state[n] = "failed"

RetryBoundSafety ==
    \A n \in Nodes : attempts[n] <= MAX_RETRIES

TerminalStateSafety ==
    \A n \in Nodes :
        /\ future[n] = "resolved" => state[n] = "succeeded"
        /\ future[n] = "rejected" => state[n] = "failed"

=============================================================================
CONSTANT MAX_RETRIES = 1

SPECIFICATION Spec

INVARIANTS
    TypeOK
    CreationSafety
    DependencySafety
    FutureConsistency
    RetryBoundSafety
    TerminalStateSafety
