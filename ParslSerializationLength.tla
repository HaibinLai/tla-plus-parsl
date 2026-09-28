--------------------------- MODULE ParslSerializationLength ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Length validation at the serialization framing boundary.
 *
 * pack_buffers prefixes each buffer with a decimal byte count.  A receiver
 * should reject a frame whose declared length differs from the bytes present.
 * The current unpack_buffers implementation slices without checking this
 * condition; STRICT_LENGTH models the corrected behavior.
 ***************************************************************************)

CONSTANT STRICT_LENGTH

States == {"wire", "accepted", "rejected"}

VARIABLES state, declaredLength, actualLength
vars == <<state, declaredLength, actualLength>>

Init ==
    /\ STRICT_LENGTH \in BOOLEAN
    /\ state = "wire"
    /\ declaredLength = 5
    /\ actualLength = 3

ParseFrame ==
    /\ state = "wire"
    /\ state' = IF declaredLength = actualLength \/ ~STRICT_LENGTH
                   THEN "accepted" ELSE "rejected"
    /\ UNCHANGED <<declaredLength, actualLength>>

ReceiveCompleteFrame ==
    /\ state = "wire"
    /\ declaredLength = actualLength
    /\ state' = "accepted"
    /\ UNCHANGED <<declaredLength, actualLength>>

Next ==
    \/ ParseFrame
    \/ ReceiveCompleteFrame
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in States
    /\ declaredLength \in Nat
    /\ actualLength \in Nat

LengthSafety ==
    state = "accepted" => declaredLength = actualLength

=============================================================================
