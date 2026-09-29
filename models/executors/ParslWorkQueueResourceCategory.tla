--------------------------- MODULE ParslWorkQueueResourceCategory ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Work Queue resource specification schema.
 *
 * submit has a category handling branch, but the acceptable_fields set omits
 * "category".  USE_FIXED models including it in the accepted schema.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES resourceKey, phase, accepted, taskMapped
vars == <<resourceKey, phase, accepted, taskMapped>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ resourceKey = "category"
    /\ phase = "new"
    /\ accepted = FALSE
    /\ taskMapped = FALSE

Validate ==
    /\ resourceKey = "category"
    /\ phase = "new"
    /\ phase' = "validated"
    /\ accepted' = USE_FIXED
    /\ taskMapped' = USE_FIXED
    /\ UNCHANGED resourceKey

Next ==
    \/ Validate
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ resourceKey = "category"
    /\ phase \in {"new", "validated"}
    /\ accepted \in BOOLEAN
    /\ taskMapped \in BOOLEAN

CategoryAcceptanceSafety ==
    phase = "validated" => accepted

=============================================================================
