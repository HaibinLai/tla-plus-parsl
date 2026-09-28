--------------------------- MODULE ParslSerializationWire ---------------------------
EXTENDS Naturals, FiniteSets

(***************************************************************************
 * Concrete Parsl serialization/framing abstraction.
 *
 * pack_apply_message serializes function, args, and kwargs separately, adds
 * serializer identifiers, then prefixes each buffer with its decimal length.
 * This model preserves that order and rejects malformed or unserializable
 * buffers before dispatch.
 ***************************************************************************)

INDICES == 0..2
CONSTANT SERIALIZABLE
BufferStates == {"raw", "serialized", "framed", "unpacked", "decoded", "failed"}
MessageStates == {"open", "rejected", "dispatched"}
Headers == {"C2", "02", "bad"}

Header(i) == IF i = 0 THEN "C2" ELSE "02"

VARIABLES bufferState, headerState, lengthValid, messageState,
          nextFrame, nextUnpack, nextDecode
vars == <<bufferState, headerState, lengthValid, messageState,
          nextFrame, nextUnpack, nextDecode>>

Init ==
    /\ SERIALIZABLE \subseteq INDICES
    /\ bufferState = [i \in INDICES |-> "raw"]
    /\ headerState = [i \in INDICES |-> "bad"]
    /\ lengthValid = [i \in INDICES |-> FALSE]
    /\ messageState = "open"
    /\ nextFrame = 0
    /\ nextUnpack = 0
    /\ nextDecode = 0

Serialize(i) ==
    /\ i \in INDICES
    /\ i \in SERIALIZABLE
    /\ bufferState[i] = "raw"
    /\ bufferState' = [bufferState EXCEPT ![i] = "serialized"]
    /\ UNCHANGED <<headerState, lengthValid, messageState,
                    nextFrame, nextUnpack, nextDecode>>

SerializationFailure(i) ==
    /\ i \in INDICES
    /\ i \notin SERIALIZABLE
    /\ bufferState[i] = "raw"
    /\ bufferState' = [bufferState EXCEPT ![i] = "failed"]
    /\ messageState' = "rejected"
    /\ UNCHANGED <<headerState, lengthValid, nextFrame,
                    nextUnpack, nextDecode>>

Frame(i) ==
    /\ i = nextFrame
    /\ i \in INDICES
    /\ bufferState[i] = "serialized"
    /\ bufferState' = [bufferState EXCEPT ![i] = "framed"]
    /\ headerState' = [headerState EXCEPT ![i] = Header(i)]
    /\ lengthValid' = [lengthValid EXCEPT ![i] = TRUE]
    /\ nextFrame' = nextFrame + 1
    /\ UNCHANGED <<messageState, nextUnpack, nextDecode>>

CorruptFrame(i) ==
    /\ i \in INDICES
    /\ bufferState[i] = "framed"
    /\ bufferState' = [bufferState EXCEPT ![i] = "failed"]
    /\ headerState' = [headerState EXCEPT ![i] = "bad"]
    /\ lengthValid' = [lengthValid EXCEPT ![i] = FALSE]
    /\ messageState' = "rejected"
    /\ UNCHANGED <<nextFrame, nextUnpack, nextDecode>>

Unpack(i) ==
    /\ i = nextUnpack
    /\ i \in INDICES
    /\ messageState = "open"
    /\ bufferState[i] = "framed"
    /\ headerState[i] = Header(i)
    /\ lengthValid[i]
    /\ bufferState' = [bufferState EXCEPT ![i] = "unpacked"]
    /\ nextUnpack' = nextUnpack + 1
    /\ UNCHANGED <<headerState, lengthValid, messageState,
                    nextFrame, nextDecode>>

Decode(i) ==
    /\ i = nextDecode
    /\ i \in INDICES
    /\ messageState = "open"
    /\ bufferState[i] = "unpacked"
    /\ bufferState' = [bufferState EXCEPT ![i] = "decoded"]
    /\ nextDecode' = nextDecode + 1
    /\ UNCHANGED <<headerState, lengthValid, messageState,
                    nextFrame, nextUnpack>>

Dispatch ==
    /\ messageState = "open"
    /\ nextDecode = 3
    /\ \A i \in INDICES : bufferState[i] = "decoded"
    /\ messageState' = "dispatched"
    /\ UNCHANGED <<bufferState, headerState, lengthValid,
                    nextFrame, nextUnpack, nextDecode>>

Next ==
    \/ \E i \in INDICES : Serialize(i) \/ SerializationFailure(i)
    \/ \E i \in INDICES : Frame(i) \/ CorruptFrame(i)
    \/ \E i \in INDICES : Unpack(i) \/ Decode(i)
    \/ Dispatch
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ bufferState \in [INDICES -> BufferStates]
    /\ headerState \in [INDICES -> Headers]
    /\ lengthValid \in [INDICES -> BOOLEAN]
    /\ messageState \in MessageStates
    /\ nextFrame \in 0..3
    /\ nextUnpack \in 0..3
    /\ nextDecode \in 0..3

HeaderSafety ==
    \A i \in INDICES :
        bufferState[i] \in {"framed", "unpacked", "decoded"}
            => /\ headerState[i] = Header(i)
               /\ lengthValid[i]

OrderingSafety ==
    /\ (messageState = "open" /\ nextFrame = 3)
          => \A i \in INDICES : bufferState[i] \in {"framed", "unpacked", "decoded"}
    /\ (messageState = "open" /\ nextUnpack = 3)
          => \A i \in INDICES : bufferState[i] \in {"unpacked", "decoded"}
    /\ (messageState = "open" /\ nextDecode = 3)
          => \A i \in INDICES : bufferState[i] = "decoded"

DispatchSafety ==
    messageState = "dispatched" =>
        /\ nextDecode = 3
        /\ \A i \in INDICES : bufferState[i] = "decoded"

FailureSafety ==
    messageState = "rejected" => messageState # "dispatched"

=============================================================================
