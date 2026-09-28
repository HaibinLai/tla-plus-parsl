--------------------------- MODULE ParslSerializationSnapshot ---------------------------
EXTENDS Naturals, Integers

(***************************************************************************
 * A one-task abstraction of Parsl's serializer snapshot boundary.
 *
 * pack_apply_message serializes the callable, args, and kwargs before the
 * message is sent.  Later mutation of the original Python object graph must
 * not change the bytes already captured on the wire.
 ***************************************************************************)

CONSTANT MAX_VERSION

PHASES == {"new", "captured", "decoded", "failed"}

VARIABLES phase, sourceVersion, capturedVersion, decodedVersion, payload
vars == <<phase, sourceVersion, capturedVersion, decodedVersion, payload>>

Init ==
    /\ MAX_VERSION > 0
    /\ phase = "new"
    /\ sourceVersion = 0
    /\ capturedVersion = (-1)
    /\ decodedVersion = (-1)
    /\ payload = (-1)

Capture ==
    /\ phase = "new"
    /\ capturedVersion' = sourceVersion
    /\ payload' = sourceVersion
    /\ phase' = "captured"
    /\ UNCHANGED <<sourceVersion, decodedVersion>>

MutateSource ==
    /\ phase \in {"captured", "decoded"}
    /\ sourceVersion < MAX_VERSION
    /\ sourceVersion' = sourceVersion + 1
    /\ UNCHANGED <<phase, capturedVersion, decodedVersion, payload>>

Decode ==
    /\ phase = "captured"
    /\ payload # (-1)
    /\ decodedVersion' = capturedVersion
    /\ phase' = "decoded"
    /\ UNCHANGED <<sourceVersion, capturedVersion, payload>>

SerializationFailure ==
    /\ phase = "new"
    /\ phase' = "failed"
    /\ UNCHANGED <<sourceVersion, capturedVersion, decodedVersion, payload>>

Next ==
    \/ Capture
    \/ MutateSource
    \/ Decode
    \/ SerializationFailure
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ phase \in PHASES
    /\ sourceVersion \in 0..MAX_VERSION
    /\ capturedVersion \in (-1)..MAX_VERSION
    /\ decodedVersion \in (-1)..MAX_VERSION
    /\ payload \in (-1)..MAX_VERSION

SnapshotSafety ==
    phase \in {"captured", "decoded"} => capturedVersion = payload

DecodeSafety ==
    phase = "decoded" => decodedVersion = capturedVersion

MutationIsolation ==
    phase = "decoded" => decodedVersion = payload

FailureSafety ==
    phase = "failed" => payload = (-1)

=============================================================================
