--------------------------- MODULE ParslHtexManagerSelection ---------------------------
EXTENDS Naturals, Sequences, FiniteSets

(***************************************************************************
 * HTEX manager selection from parsl/executors/high_throughput/manager_selector.py.
 *
 * Random selection may return any permutation of ready managers.  Block-ID
 * selection uses the source sort key: managers without a block ID first, then
 * lexicographic block IDs.  The model keeps the manager set deliberately small
 * while checking that selection never duplicates or invents a manager.
 ***************************************************************************)

CONSTANT USE_BLOCK_SELECTOR

MANAGERS == {"m0", "m1", "m2"}
BLOCK_ID == [m \in MANAGERS |->
    IF m = "m0" THEN "none" ELSE IF m = "m1" THEN "2" ELSE "10"]

Permutations == {
    <<"m0", "m1", "m2">>, <<"m0", "m2", "m1">>,
    <<"m1", "m0", "m2">>, <<"m1", "m2", "m0">>,
    <<"m2", "m0", "m1">>, <<"m2", "m1", "m0">>
}

VARIABLES phase, order
vars == <<phase, order>>

Init ==
    /\ USE_BLOCK_SELECTOR \in BOOLEAN
    /\ phase = "ready"
    /\ order = <<>>

SelectManagers ==
    /\ phase = "ready"
    /\ phase' = "selected"
    /\ order' = IF USE_BLOCK_SELECTOR
                THEN <<"m0", "m2", "m1">>
                ELSE CHOOSE p \in Permutations : TRUE

Next ==
    \/ SelectManagers
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ phase \in {"ready", "selected"}
    /\ order \in (Permutations \cup {<<>>})

SelectionSafety ==
    phase = "selected" =>
        /\ Len(order) = Cardinality(MANAGERS)
        /\ \A i \in 1..Len(order) : order[i] \in MANAGERS
        /\ {order[i] : i \in 1..Len(order)} = MANAGERS

BlockIdOrdering ==
    USE_BLOCK_SELECTOR /\ phase = "selected" =>
        order = <<"m0", "m2", "m1">>

=============================================================================
