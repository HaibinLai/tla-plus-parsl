--------------------------- MODULE ParslSerializationShortFrameCount ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Short apply-message frame count in unpack_and_deserialize.
 *
 * The protocol expects exactly three buffers.  The current implementation
 * deserializes the available frames and only then asserts the count, so a
 * truncated two-frame message still executes deserializer work.  The fixed
 * branch rejects the count before decoding any payload.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES state, decodedFrames, rejected
vars == <<state, decodedFrames, rejected>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ state = "framed"
    /\ decodedFrames = 0
    /\ rejected = FALSE

ValidateFrameCount ==
    /\ state = "framed"
    /\ IF USE_FIXED
          THEN /\ state' = "rejected"
               /\ decodedFrames' = 0
               /\ rejected' = TRUE
          ELSE /\ state' = "decoding"
               /\ UNCHANGED <<decodedFrames, rejected>>

DecodeShortFrames ==
    /\ state = "decoding"
    /\ state' = "rejected"
    /\ decodedFrames' = 2
    /\ rejected' = TRUE

Next == ValidateFrameCount \/ DecodeShortFrames \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ state \in {"framed", "decoding", "rejected"}
    /\ decodedFrames \in 0..2
    /\ rejected \in BOOLEAN

ShortDecodeSafety ==
    rejected => decodedFrames = 0

=============================================================================
