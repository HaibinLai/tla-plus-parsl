--------------------------- MODULE ParslFunctionObjectTransport ---------------------------
EXTENDS Naturals, Integers

(***************************************************************************
 * Function and object-content snapshot across Parsl's serialized task path.
 *
 * ``pack_apply_message`` serializes the callable, positional arguments, and
 * keyword arguments before the resulting bytes are handed to a ZMQ sender.
 * The source object may change while those bytes are queued or in flight, but
 * the receiver must decode the captured snapshot rather than the later source
 * value.  This is a deliberately small model of that boundary, not a model
 * of Python bytecode or dill internals.
 ***************************************************************************)

CONSTANT MAX_VERSION

FrameStates == {"new", "serialized", "queued", "received", "decoded", "executed"}

VARIABLES sourceVersion, capturedVersion, frame,
          decodedVersion, result
vars == <<sourceVersion, capturedVersion, frame, decodedVersion, result>>

Init ==
    /\ MAX_VERSION >= 1
    /\ sourceVersion = 0
    /\ capturedVersion = -1
    /\ frame = "new"
    /\ decodedVersion = -1
    /\ result = -1

Serialize ==
    /\ frame = "new"
    /\ capturedVersion' = sourceVersion
    /\ frame' = "serialized"
    /\ UNCHANGED <<sourceVersion, decodedVersion, result>>

Queue ==
    /\ frame = "serialized"
    /\ frame' = "queued"
    /\ UNCHANGED <<sourceVersion, capturedVersion, decodedVersion, result>>

MutateSource ==
    /\ frame \in {"serialized", "queued", "received"}
    /\ sourceVersion < MAX_VERSION
    /\ sourceVersion' = sourceVersion + 1
    /\ UNCHANGED <<capturedVersion, frame, decodedVersion, result>>

Receive ==
    /\ frame = "queued"
    /\ frame' = "received"
    /\ UNCHANGED <<sourceVersion, capturedVersion, decodedVersion, result>>

Decode ==
    /\ frame = "received"
    /\ decodedVersion' = capturedVersion
    /\ frame' = "decoded"
    /\ UNCHANGED <<sourceVersion, capturedVersion, result>>

Execute ==
    /\ frame = "decoded"
    /\ result' = decodedVersion + 1
    /\ frame' = "executed"
    /\ UNCHANGED <<sourceVersion, capturedVersion, decodedVersion>>

Next ==
    \/ Serialize
    \/ Queue
    \/ MutateSource
    \/ Receive
    \/ Decode
    \/ Execute
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ sourceVersion \in 0..MAX_VERSION
    /\ capturedVersion \in -1..MAX_VERSION
    /\ frame \in FrameStates
    /\ decodedVersion \in -1..MAX_VERSION
    /\ result \in -1..(MAX_VERSION + 1)

SnapshotSafety ==
    frame \in {"decoded", "executed"} => decodedVersion = capturedVersion

ContentIsolation ==
    frame \in {"serialized", "queued", "received", "decoded", "executed"}
        => capturedVersion <= sourceVersion

ExecutionUsesSnapshot ==
    frame = "executed" => result = capturedVersion + 1

=============================================================================
