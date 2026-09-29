--------------------------- MODULE ParslAwsStatusMissingResult ---------------------------
EXTENDS Naturals

(***************************************************************************
 * AWSProvider.status result cardinality.
 *
 * The provider API is queried with one requested instance id.  EC2 may
 * return no matching reservation (for example after termination).  The
 * current implementation returns an empty status list, while callers expect
 * one status per requested id.  USE_FIXED models an explicit UNKNOWN result.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES state, returnedCount, returnedState
vars == <<state, returnedCount, returnedState>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ state = "missing"
    /\ returnedCount = 0
    /\ returnedState = "none"

HandleMissing ==
    /\ state = "missing"
    /\ state' = "handled"
    /\ returnedCount' = IF USE_FIXED THEN 1 ELSE 0
    /\ returnedState' = IF USE_FIXED THEN "unknown" ELSE "none"

Next == HandleMissing \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ state \in {"missing", "handled"}
    /\ returnedCount \in Nat
    /\ returnedState \in {"none", "unknown"}

CardinalitySafety == state = "handled" => returnedCount = 1
StateSafety == returnedCount = 1 => returnedState = "unknown"

=============================================================================
