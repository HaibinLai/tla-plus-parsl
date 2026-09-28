--------------------------- MODULE ParslJoinListMutation ---------------------------
EXTENDS Naturals

(***************************************************************************
 * A join_app result list is stored in the task record before callbacks run.
 * The current path aliases the mutable list; the FIXED branch snapshots its
 * membership when the join is registered.
 *************************************************************************** *)

CONSTANTS MUTATE_LIST, USE_FIXED
VARIABLES state, joinCount, resultCount
vars == <<state, joinCount, resultCount>>

Init ==
    /\ MUTATE_LIST \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ state = "joining"
    /\ joinCount = 2
    /\ resultCount = 0

MutateBeforeCallback ==
    /\ state = "joining"
    /\ MUTATE_LIST
    /\ state' = "mutated"
    /\ joinCount' = IF USE_FIXED THEN 2 ELSE 0
    /\ UNCHANGED resultCount

Callback ==
    /\ state \in {"joining", "mutated"}
    /\ ~MUTATE_LIST \/ state = "mutated"
    /\ state' = "done"
    /\ resultCount' = joinCount
    /\ UNCHANGED joinCount

Next ==
    \/ MutateBeforeCallback
    \/ Callback
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in {"joining", "mutated", "done"}
    /\ joinCount \in Nat
    /\ resultCount \in Nat

JoinSnapshotSafety == state = "done" => resultCount = 2

=============================================================================
