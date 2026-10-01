--------------------------- MODULE ParslZMQSerializedAck ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Serialized callable/object snapshot over a bounded ZMQ-like ACK/retry path.
 *
 * Encoding captures the source object version.  A lost ACK permits one
 * retransmission of the same envelope.  The Current branch dispatches that
 * duplicate twice; the Fixed branch deduplicates by envelope identity and
 * preserves the serialized snapshot even if the submitter mutates its source.
 ***************************************************************************)

CONSTANT USE_FIXED

WireStates == {"none", "encoded", "queued", "delivered", "decoded", "rejected"}
TaskStates == {"pending", "running", "succeeded", "failed"}

VARIABLES sourceVersion, capturedVersion, wire, sendCount, delivered,
          acked, seen, dispatchCount, task, future

vars == <<sourceVersion, capturedVersion, wire, sendCount, delivered,
           acked, seen, dispatchCount, task, future>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ sourceVersion = 0
    /\ capturedVersion = 0
    /\ wire = "none"
    /\ sendCount = 0
    /\ delivered = 0
    /\ acked = FALSE
    /\ seen = FALSE
    /\ dispatchCount = 0
    /\ task = "pending"
    /\ future = "unresolved"

MutateSource ==
    /\ sourceVersion = 0
    /\ capturedVersion = 0
    /\ sourceVersion' = 1
    /\ UNCHANGED <<capturedVersion, wire, sendCount, delivered, acked,
                    seen, dispatchCount, task, future>>

Encode ==
    /\ wire = "none"
    /\ sendCount = 0
    /\ sourceVersion = 0
    /\ capturedVersion' = sourceVersion
    /\ wire' = "encoded"
    /\ UNCHANGED <<sourceVersion, sendCount, delivered, acked, seen,
                    dispatchCount, task, future>>

Send ==
    /\ wire = "encoded"
    /\ sendCount < 2
    /\ wire' = "queued"
    /\ sendCount' = sendCount + 1
    /\ UNCHANGED <<sourceVersion, capturedVersion, delivered, acked, seen,
                    dispatchCount, task, future>>

Deliver ==
    /\ wire = "queued"
    /\ delivered' = delivered + 1
    /\ wire' = "delivered"
    /\ UNCHANGED <<sourceVersion, capturedVersion, sendCount, acked, seen,
                    dispatchCount, task, future>>

LoseAck ==
    /\ wire = "delivered"
    /\ ~acked
    /\ wire' = "none"
    /\ UNCHANGED <<sourceVersion, capturedVersion, sendCount, delivered,
                    acked, seen, dispatchCount, task, future>>

Retransmit ==
    /\ wire = "none"
    /\ sendCount = 1
    /\ ~acked
    /\ wire' = "encoded"
    /\ UNCHANGED <<sourceVersion, capturedVersion, sendCount, delivered,
                    acked, seen, dispatchCount, task, future>>

Decode ==
    /\ wire = "delivered"
    /\ wire' = "decoded"
    /\ UNCHANGED <<sourceVersion, capturedVersion, sendCount, delivered,
                    acked, seen, dispatchCount, task, future>>

DispatchFirst ==
    /\ wire = "decoded"
    /\ ~seen
    /\ wire' = "none"
    /\ seen' = TRUE
    /\ dispatchCount' = dispatchCount + 1
    /\ task' = "running"
    /\ UNCHANGED <<sourceVersion, capturedVersion, sendCount, delivered,
                    acked, future>>

DispatchDuplicate ==
    /\ wire = "decoded"
    /\ seen
    /\ wire' = "none"
    /\ dispatchCount' = IF USE_FIXED THEN dispatchCount ELSE dispatchCount + 1
    /\ UNCHANGED <<sourceVersion, capturedVersion, sendCount, delivered,
                    acked, seen, task, future>>

Complete ==
    /\ task = "running"
    /\ dispatchCount > 0
    /\ task' = "succeeded"
    /\ future' = "resolved"
    /\ acked' = TRUE
    /\ UNCHANGED <<sourceVersion, capturedVersion, wire, sendCount, delivered,
                    seen, dispatchCount>>

Next ==
    \/ MutateSource
    \/ Encode
    \/ Send
    \/ Retransmit
    \/ Deliver
    \/ LoseAck
    \/ Decode
    \/ DispatchFirst
    \/ DispatchDuplicate
    \/ Complete
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ sourceVersion \in 0..1
    /\ capturedVersion \in 0..1
    /\ wire \in WireStates
    /\ sendCount \in 0..2
    /\ delivered \in 0..2
    /\ acked \in BOOLEAN
    /\ seen \in BOOLEAN
    /\ dispatchCount \in 0..2
    /\ task \in TaskStates
    /\ future \in {"unresolved", "resolved"}

SnapshotSafety == capturedVersion = 0
SingleDispatch == dispatchCount <= 1
FutureConsistency == future = "resolved" => task = "succeeded"
AckSafety == acked => task = "succeeded"

=============================================================================
