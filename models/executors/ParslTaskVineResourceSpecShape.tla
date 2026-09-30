--------------------------- MODULE ParslTaskVineResourceSpecShape ---------------------------
EXTENDS Naturals

(***************************************************************************
 * TaskVineExecutor.submit calls resource_specification.get before validating
 * the documented mapping shape.  USE_FIXED turns a malformed specification
 * into a controlled rejection instead of leaking AttributeError.
 ***************************************************************************)

CONSTANT USE_FIXED, SPEC_IS_MAPPING

VARIABLES admitted, outcome
vars == <<admitted, outcome>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ SPEC_IS_MAPPING \in BOOLEAN
    /\ admitted = FALSE
    /\ outcome = "pending"

Submit ==
    /\ IF SPEC_IS_MAPPING
          THEN /\ admitted' = TRUE
               /\ outcome' = "queued"
          ELSE IF USE_FIXED
               THEN /\ admitted' = FALSE
                    /\ outcome' = "rejected"
               ELSE /\ admitted' = FALSE
                    /\ outcome' = "attribute-error"

Next == Submit \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ SPEC_IS_MAPPING \in BOOLEAN
    /\ admitted \in BOOLEAN
    /\ outcome \in {"pending", "queued", "rejected", "attribute-error"}

MalformedInputSafety ==
    SPEC_IS_MAPPING \/ (outcome = "pending" \/ outcome = "rejected")

=============================================================================
