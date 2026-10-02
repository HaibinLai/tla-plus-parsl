--------------------------- MODULE ParslJoinImmediateMutation ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Composition of two join_app boundaries:
 *
 * 1. registering an already-completed first Future invokes its callback
 *    immediately, while the second Future is still pending;
 * 2. the mutable list returned by the join body is changed before the second
 *    callback runs.
 *
 * A stable join snapshot must preserve both positions across this interleaving.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES firstSeen, members, secondDone, outer, resultCount
vars == <<firstSeen, members, secondDone, outer, resultCount>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ firstSeen = FALSE
    /\ members = 2
    /\ secondDone = FALSE
    /\ outer = "joining"
    /\ resultCount = 0

ImmediateFirstCallback ==
    /\ ~firstSeen
    /\ firstSeen' = TRUE
    /\ UNCHANGED <<members, secondDone, outer, resultCount>>

MutateReturnedList ==
    /\ firstSeen
    /\ members' = IF USE_FIXED THEN 2 ELSE 1
    /\ UNCHANGED <<firstSeen, secondDone, outer, resultCount>>

CompleteSecond ==
    /\ firstSeen
    /\ ~secondDone
    /\ secondDone' = TRUE
    /\ IF members = 1
          THEN /\ outer' = "done"
               /\ resultCount' = 1
          ELSE /\ outer' = "done"
               /\ resultCount' = 2
    /\ UNCHANGED <<firstSeen, members>>

Next == ImmediateFirstCallback \/ MutateReturnedList \/ CompleteSecond \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ firstSeen \in BOOLEAN
    /\ members \in 1..2
    /\ secondDone \in BOOLEAN
    /\ outer \in {"joining", "done"}
    /\ resultCount \in 0..2

ResultShape == outer = "done" => resultCount = 2

=============================================================================
