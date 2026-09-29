--------------------------- MODULE ParslLSFResourceValidation ---------------------------
EXTENDS Integers

(***************************************************************************
 * LSF resource derivation when requesting by cores.
 *
 * LSFProvider rejects a zero cores_per_node value, but the current
 * constructor accepts a negative value and computes a negative node count.
 * USE_FIXED models rejecting every non-positive cores_per_node input.
 *************************************************************************** *)

CONSTANTS CORES_KIND, USE_FIXED
Kinds == {"negative", "zero", "positive"}
States == {"unvalidated", "accepted", "rejected"}

VARIABLES state
vars == <<state>>

Init ==
    /\ CORES_KIND \in Kinds
    /\ USE_FIXED \in BOOLEAN
    /\ state = "unvalidated"

Validate ==
    /\ state = "unvalidated"
    /\ state' = IF (CORES_KIND = "negative" \/ CORES_KIND = "zero") /\ USE_FIXED
                   THEN "rejected" ELSE "accepted"

Next ==
    \/ Validate
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ CORES_KIND \in Kinds
    /\ USE_FIXED \in BOOLEAN
    /\ state \in States

ResourceSafety ==
    state = "accepted" => CORES_KIND = "positive"

=============================================================================
