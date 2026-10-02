------------------------- MODULE ParslApplyFrameValidation -------------------------
EXTENDS Naturals

(***************************************************************************
 * Combined apply-message framing validation.
 *
 * `unpack_and_deserialize` expects three buffers, each with a decimal byte
 * length.  The Current branch invokes deserialize before rejecting an invalid
 * frame count or truncated payload.  The Fixed branch validates both wire
 * properties before any decode side effect.
 ***************************************************************************)

CONSTANTS BAD_COUNT, BAD_LENGTH, USE_FIXED
States == {"framed", "decoded", "rejected"}

VARIABLES state, frameCount, declaredLength, availableLength, decodedCount
vars == <<state, frameCount, declaredLength, availableLength, decodedCount>>

Init ==
    /\ BAD_COUNT \in BOOLEAN
    /\ BAD_LENGTH \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ state = "framed"
    /\ frameCount = IF BAD_COUNT THEN 4 ELSE 3
    /\ declaredLength = IF BAD_LENGTH THEN 5 ELSE 3
    /\ availableLength = 3
    /\ decodedCount = 0

Unpack ==
    /\ state = "framed"
    /\ IF USE_FIXED
          THEN IF frameCount = 3 /\ declaredLength = availableLength
               THEN /\ state' = "decoded"
                    /\ decodedCount' = 3
               ELSE /\ state' = "rejected"
                    /\ UNCHANGED decodedCount
          ELSE IF frameCount = 3 /\ declaredLength = availableLength
               THEN /\ state' = "decoded"
                    /\ decodedCount' = 3
               ELSE /\ state' = "rejected"
                    /\ decodedCount' = 1
    /\ UNCHANGED <<frameCount, declaredLength, availableLength>>

Next ==
    \/ Unpack
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ BAD_COUNT \in BOOLEAN
    /\ BAD_LENGTH \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ state \in States
    /\ frameCount \in 3..4
    /\ declaredLength \in 0..5
    /\ availableLength \in 0..3
    /\ decodedCount \in 0..3

DecodeSideEffectSafety ==
    (BAD_COUNT \/ BAD_LENGTH) => decodedCount = 0

ValidDecodeSafety ==
    state = "decoded" =>
        /\ frameCount = 3
        /\ declaredLength = availableLength
        /\ decodedCount = 3

=============================================================================
CONSTANTS
    BAD_COUNT = TRUE
    BAD_LENGTH = TRUE
    USE_FIXED = TRUE

SPECIFICATION Spec

INVARIANTS
    TypeOK
    DecodeSideEffectSafety
    ValidDecodeSafety
