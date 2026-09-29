--------------------------- MODULE ParslSerializationTruncatedLength ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Declared-length validation in unpack_and_deserialize.
 *
 * A packed frame declares its byte length before the payload.  The current
 * slicing path accepts a declaration longer than the bytes that remain and
 * passes the short payload to deserialize.  The fixed branch validates the
 * available length before invoking a deserializer.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES phase, decoded, rejected
vars == <<phase, decoded, rejected>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ phase = "framed"
    /\ decoded = FALSE
    /\ rejected = FALSE

ValidateLength ==
    /\ phase = "framed"
    /\ IF USE_FIXED
          THEN /\ phase' = "rejected"
               /\ decoded' = FALSE
               /\ rejected' = TRUE
          ELSE /\ phase' = "decoding"
               /\ UNCHANGED <<decoded, rejected>>

DecodeTruncatedPayload ==
    /\ phase = "decoding"
    /\ phase' = "rejected"
    /\ decoded' = TRUE
    /\ rejected' = TRUE

Next == ValidateLength \/ DecodeTruncatedPayload \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ phase \in {"framed", "decoding", "rejected"}
    /\ decoded \in BOOLEAN
    /\ rejected \in BOOLEAN

TruncatedDecodeSafety ==
    rejected => ~decoded

=============================================================================
