--------------------------- MODULE ParslSerializerHeaderConsistency ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Serializer-header and body consistency.
 *
 * parsl.serialize.facade.serialize emits ``identifier + newline + body``.
 * deserialize dispatches solely on the identifier.  The model separates the
 * serializer that produced the body from the header seen by the receiver.
 * A mismatched header must not be accepted as a valid decoded object.
 ***************************************************************************
 *)

CONSTANTS OBJECT_KIND, USE_FIXED

Kinds == {"callable", "data"}
Headers == {"C2", "02", "unknown"}
States == {"new", "encoded", "corrupted", "decoded", "rejected"}

ExpectedHeader(k) == IF k = "callable" THEN "C2" ELSE "02"
OtherHeader(k) == IF k = "callable" THEN "02" ELSE "C2"

VARIABLES bodyKind, wireHeader, state, resultKind
vars == <<bodyKind, wireHeader, state, resultKind>>

Init ==
    /\ OBJECT_KIND \in Kinds
    /\ USE_FIXED \in BOOLEAN
    /\ bodyKind = OBJECT_KIND
    /\ wireHeader = "unknown"
    /\ state = "new"
    /\ resultKind = "none"

Encode ==
    /\ state = "new"
    /\ wireHeader' = ExpectedHeader(bodyKind)
    /\ state' = "encoded"
    /\ UNCHANGED <<bodyKind, resultKind>>

CorruptHeader ==
    /\ state = "encoded"
    /\ wireHeader' = OtherHeader(bodyKind)
    /\ state' = "corrupted"
    /\ UNCHANGED <<bodyKind, resultKind>>

Decode ==
    /\ state \in {"encoded", "corrupted"}
    /\ IF wireHeader = ExpectedHeader(bodyKind)
       THEN /\ state' = "decoded"
            /\ resultKind' = bodyKind
       ELSE IF USE_FIXED
            THEN /\ state' = "rejected"
                 /\ resultKind' = "none"
            ELSE /\ state' = "decoded"
                 /\ resultKind' = bodyKind
    /\ UNCHANGED <<bodyKind, wireHeader>>

Next ==
    \/ Encode
    \/ CorruptHeader
    \/ Decode
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ bodyKind \in Kinds
    /\ wireHeader \in Headers
    /\ state \in States
    /\ resultKind \in Kinds \cup {"none", "wrong"}

HeaderSafety ==
    state = "decoded" => wireHeader = ExpectedHeader(bodyKind)

ResultContentSafety ==
    state = "decoded" => resultKind = bodyKind

RejectedMismatchSafety ==
    state = "rejected" => wireHeader # ExpectedHeader(bodyKind)

=============================================================================
