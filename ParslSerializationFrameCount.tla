--------------------------- MODULE ParslSerializationFrameCount ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Extra-frame handling in unpack_and_deserialize.
 *
 * The apply-message protocol expects exactly three buffers. The current
 * implementation deserializes every framed buffer first and checks len == 3
 * only afterward, so an extra frame can execute deserializer work before the
 * malformed message is rejected. The FIXED branch validates the frame count
 * before decoding any payload.
 *************************************************************************** *)

CONSTANTS EXTRA_FRAME, USE_FIXED
VARIABLES state, decodedFrames, rejected
vars == <<state, decodedFrames, rejected>>

Init ==
    /\ EXTRA_FRAME \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ state = "framed"
    /\ decodedFrames = 0
    /\ rejected = FALSE

ValidateFrameCount ==
    /\ state = "framed"
    /\ EXTRA_FRAME
    /\ IF USE_FIXED
          THEN /\ state' = "rejected"
               /\ decodedFrames' = 0
               /\ rejected' = TRUE
          ELSE /\ state' = "decoding"
               /\ UNCHANGED <<decodedFrames, rejected>>

DecodeFrames ==
    /\ state = "framed"
    /\ ~EXTRA_FRAME
    /\ state' = "completed"
    /\ decodedFrames' = 3
    /\ UNCHANGED rejected

DecodeExtraFrames ==
    /\ state = "decoding"
    /\ EXTRA_FRAME
    /\ state' = "rejected"
    /\ decodedFrames' = 4
    /\ rejected' = TRUE

Next ==
    \/ ValidateFrameCount
    \/ DecodeFrames
    \/ DecodeExtraFrames
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in {"framed", "decoding", "completed", "rejected"}
    /\ decodedFrames \in 0..4
    /\ rejected \in BOOLEAN

ExtraDecodeSafety ==
    EXTRA_FRAME => decodedFrames = 0

=============================================================================
