--------------------------- MODULE ParslSerializationBinaryPayload ---------------------------
EXTENDS Naturals, Sequences

(***************************************************************************
 * Binary payload preservation through Parsl's length-prefixed framing.
 *
 * pack_buffers stores a decimal byte length followed by raw bytes.  The
 * payload may contain newline bytes, NUL bytes, and values outside ASCII;
 * framing must use the declared length rather than splitting on payload
 * content.  This model follows one bounded payload from encode to decode.
 *************************************************************************** *)

CONSTANT PAYLOAD_KIND

Payloads ==
    [empty |-> <<>>,
     newline |-> <<97, 10, 98>>,
     binary |-> <<0, 10, 255, 128>>]

VARIABLES source, wireLength, wirePayload, decoded, state
vars == <<source, wireLength, wirePayload, decoded, state>>

Init ==
    /\ PAYLOAD_KIND \in {"empty", "newline", "binary"}
    /\ source = Payloads[PAYLOAD_KIND]
    /\ wireLength = 0
    /\ wirePayload = <<>>
    /\ decoded = <<>>
    /\ state = "source"

Pack ==
    /\ state = "source"
    /\ wireLength' = Len(source)
    /\ wirePayload' = source
    /\ state' = "framed"
    /\ UNCHANGED <<source, decoded>>

Unpack ==
    /\ state = "framed"
    /\ wireLength = Len(wirePayload)
    /\ decoded' = wirePayload
    /\ state' = "decoded"
    /\ UNCHANGED <<source, wireLength, wirePayload>>

Next ==
    \/ Pack
    \/ Unpack
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ source \in Seq(Nat)
    /\ wirePayload \in Seq(Nat)
    /\ decoded \in Seq(Nat)
    /\ wireLength \in Nat
    /\ state \in {"source", "framed", "decoded"}

LengthSafety == state = "framed" => wireLength = Len(wirePayload)
BinaryContentSafety == state = "decoded" => decoded = source

=============================================================================
