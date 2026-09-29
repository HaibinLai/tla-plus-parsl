--------------------------- MODULE ParslZMQObjectSnapshot ---------------------------
EXTENDS Naturals, Integers

(***************************************************************************
 * Mutable Python object snapshot across a ZMQ multipart frame.
 *
 * Serialization captures an object version before the frame is queued.  The
 * current branch models a mutable payload alias that changes while the frame
 * is in flight; the fixed branch keeps the serialized bytes immutable until
 * decode.
 ***************************************************************************)

CONSTANT MAX_VERSION, USE_FIXED

FrameStates == {"new", "serialized", "queued", "received", "decoded"}

VARIABLES sourceVersion, capturedVersion, payloadVersion,
          frame, decodedVersion
vars == <<sourceVersion, capturedVersion, payloadVersion,
           frame, decodedVersion>>

Init ==
    /\ MAX_VERSION >= 1
    /\ USE_FIXED \in BOOLEAN
    /\ sourceVersion = 0
    /\ capturedVersion = -1
    /\ payloadVersion = -1
    /\ frame = "new"
    /\ decodedVersion = -1

Serialize ==
    /\ frame = "new"
    /\ capturedVersion' = sourceVersion
    /\ payloadVersion' = sourceVersion
    /\ frame' = "serialized"
    /\ UNCHANGED <<sourceVersion, decodedVersion>>

QueueFrame ==
    /\ frame = "serialized"
    /\ frame' = "queued"
    /\ UNCHANGED <<sourceVersion, capturedVersion, payloadVersion, decodedVersion>>

MutateObject ==
    /\ frame \in {"serialized", "queued", "received"}
    /\ sourceVersion < MAX_VERSION
    /\ sourceVersion' = sourceVersion + 1
    /\ payloadVersion' = IF USE_FIXED THEN payloadVersion ELSE sourceVersion + 1
    /\ UNCHANGED <<capturedVersion, frame, decodedVersion>>

ReceiveFrame ==
    /\ frame = "queued"
    /\ frame' = "received"
    /\ UNCHANGED <<sourceVersion, capturedVersion, payloadVersion, decodedVersion>>

Decode ==
    /\ frame = "received"
    /\ frame' = "decoded"
    /\ decodedVersion' = payloadVersion
    /\ UNCHANGED <<sourceVersion, capturedVersion, payloadVersion>>

Next ==
    \/ Serialize
    \/ QueueFrame
    \/ MutateObject
    \/ ReceiveFrame
    \/ Decode
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ sourceVersion \in 0..MAX_VERSION
    /\ capturedVersion \in -1..MAX_VERSION
    /\ payloadVersion \in -1..MAX_VERSION
    /\ frame \in FrameStates
    /\ decodedVersion \in -1..MAX_VERSION

FrameSnapshotSafety ==
    frame = "decoded" => decodedVersion = capturedVersion

PayloadImmutability ==
    frame \in {"serialized", "queued", "received", "decoded"}
        => payloadVersion = capturedVersion

DecodeSafety ==
    frame = "decoded" => decodedVersion = payloadVersion

=============================================================================
