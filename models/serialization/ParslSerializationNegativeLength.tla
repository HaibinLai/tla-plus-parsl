--------------------------- MODULE ParslSerializationNegativeLength ---------------------------
EXTENDS Integers

(***************************************************************************
 * Negative length validation for the length-prefixed serialization wire.
 *
 * ``unpack_buffers`` converts the decimal header to an integer and slices
 * with that value.  Python accepts a negative slice bound, so malformed
 * input can trigger a second parse failure after a partial slice.  STRICT_LENGTH
 * models a receiver that rejects negative declarations before slicing.
 *************************************************************************** *)

CONSTANTS DECLARED_KIND, STRICT_LENGTH
Kinds == {"negative", "zero", "positive"}
States == {"wire", "accepted", "rejected", "crashed"}

VARIABLES state
vars == <<state>>

Init ==
    /\ DECLARED_KIND \in Kinds
    /\ STRICT_LENGTH \in BOOLEAN
    /\ state = "wire"

ParseFrame ==
    /\ state = "wire"
    /\ state' = IF DECLARED_KIND = "negative" /\ STRICT_LENGTH
                   THEN "rejected"
                   ELSE IF DECLARED_KIND = "negative" THEN "crashed"
                   ELSE "accepted"

Next ==
    \/ ParseFrame
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ DECLARED_KIND \in Kinds
    /\ STRICT_LENGTH \in BOOLEAN
    /\ state \in States

NegativeLengthSafety ==
    state \in {"accepted", "crashed"} => DECLARED_KIND # "negative"

=============================================================================
