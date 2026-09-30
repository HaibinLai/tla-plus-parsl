--------------------------- MODULE ParslThreadExecutorEmptyResourceSpec ---------------------------
EXTENDS Naturals

(***************************************************************************
 * ThreadPoolExecutor resource-specification shape validation.
 *
 * ThreadPoolExecutor.submit only validates a resource specification inside a
 * truthy branch.  An empty non-mapping value such as [] is therefore accepted
 * and the task runs.  The fixed branch validates the mapping shape regardless
 * of truthiness.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES inputShape, outcome
vars == <<inputShape, outcome>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ inputShape = "empty-list"
    /\ outcome = "new"

Submit ==
    /\ outcome = "new"
    /\ outcome' = IF USE_FIXED THEN "rejected" ELSE "accepted"
    /\ UNCHANGED inputShape

Next == Submit \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ inputShape = "empty-list"
    /\ outcome \in {"new", "accepted", "rejected"}

InvalidShapeRejected == outcome = "accepted" => FALSE

=============================================================================
