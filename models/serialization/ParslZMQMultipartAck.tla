--------------------------- MODULE ParslZMQMultipartAck ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Multipart serializer validation on an ACK/retry path.
 *
 * A task envelope contains exactly three serialized buffers.  A lost ACK can
 * retransmit a valid envelope, but a malformed frame count must be rejected
 * before any buffer is decoded.  Receiver identity tracking makes valid
 * retransmission at-most-once at the worker boundary.
 ***************************************************************************)

CONSTANTS BAD_FRAME_COUNT, USE_FIXED

WireStates == {"none", "encoded", "queued", "delivered", "decoded", "rejected"}

VARIABLES frameCount, wire, sendCount, decoded, rejected, seen, dispatchCount,
          acked, task, future

vars == <<frameCount, wire, sendCount, decoded, rejected, seen, dispatchCount,
           acked, task, future>>

Init ==
    /\ BAD_FRAME_COUNT \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ frameCount = IF BAD_FRAME_COUNT THEN 4 ELSE 3
    /\ wire = "none"
    /\ sendCount = 0
    /\ decoded = FALSE
    /\ rejected = FALSE
    /\ seen = FALSE
    /\ dispatchCount = 0
    /\ acked = FALSE
    /\ task = "pending"
    /\ future = "unresolved"

Encode ==
    /\ wire = "none"
    /\ sendCount = 0
    /\ wire' = "encoded"
    /\ UNCHANGED <<frameCount, sendCount, decoded, rejected, seen,
                    dispatchCount, acked, task, future>>

Send ==
    /\ wire = "encoded"
    /\ sendCount < 2
    /\ wire' = "queued"
    /\ sendCount' = sendCount + 1
    /\ UNCHANGED <<frameCount, decoded, rejected, seen, dispatchCount,
                    acked, task, future>>

Deliver ==
    /\ wire = "queued"
    /\ wire' = "delivered"
    /\ UNCHANGED <<frameCount, sendCount, decoded, rejected, seen,
                    dispatchCount, acked, task, future>>

ValidateGood ==
    /\ wire = "delivered"
    /\ frameCount = 3
    /\ decoded' = TRUE
    /\ rejected' = FALSE
    /\ wire' = "decoded"
    /\ UNCHANGED <<frameCount, sendCount, seen, dispatchCount, acked, task, future>>

ValidateBadFixed ==
    /\ wire = "delivered"
    /\ frameCount = 4
    /\ USE_FIXED
    /\ decoded' = FALSE
    /\ rejected' = TRUE
    /\ wire' = "rejected"
    /\ UNCHANGED <<frameCount, sendCount, seen, dispatchCount, acked, task, future>>

ValidateBadCurrent ==
    /\ wire = "delivered"
    /\ frameCount = 4
    /\ ~USE_FIXED
    /\ decoded' = TRUE
    /\ rejected' = TRUE
    /\ wire' = "decoded"
    /\ UNCHANGED <<frameCount, sendCount, seen, dispatchCount, acked, task, future>>

DispatchFirst ==
    /\ wire = "decoded"
    /\ decoded
    /\ ~seen
    /\ wire' = "none"
    /\ seen' = TRUE
    /\ dispatchCount' = dispatchCount + 1
    /\ task' = "running"
    /\ UNCHANGED <<frameCount, sendCount, decoded, rejected, acked, future>>

DispatchDuplicate ==
    /\ wire = "decoded"
    /\ decoded
    /\ seen
    /\ wire' = "none"
    /\ dispatchCount' = IF USE_FIXED THEN dispatchCount ELSE dispatchCount + 1
    /\ UNCHANGED <<frameCount, sendCount, decoded, rejected, seen, acked, task, future>>

LoseAck ==
    /\ wire = "none"
    /\ sendCount = 1
    /\ task = "running"
    /\ ~acked
    /\ wire' = "encoded"
    /\ UNCHANGED <<frameCount, sendCount, decoded, rejected, seen,
                    dispatchCount, acked, task, future>>

Complete ==
    /\ task = "running"
    /\ dispatchCount > 0
    /\ task' = "succeeded"
    /\ future' = "resolved"
    /\ acked' = TRUE
    /\ UNCHANGED <<frameCount, wire, sendCount, decoded, rejected, seen, dispatchCount>>

Next ==
    \/ Encode
    \/ Send
    \/ Deliver
    \/ ValidateGood
    \/ ValidateBadFixed
    \/ ValidateBadCurrent
    \/ DispatchFirst
    \/ DispatchDuplicate
    \/ LoseAck
    \/ Complete
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ frameCount \in 3..4
    /\ wire \in WireStates
    /\ sendCount \in 0..2
    /\ decoded \in BOOLEAN
    /\ rejected \in BOOLEAN
    /\ seen \in BOOLEAN
    /\ dispatchCount \in 0..2
    /\ acked \in BOOLEAN
    /\ task \in {"pending", "running", "succeeded"}
    /\ future \in {"unresolved", "resolved"}

MalformedFrameSafety == BAD_FRAME_COUNT => ~decoded
SingleDispatch == dispatchCount <= 1
FutureConsistency == future = "resolved" => task = "succeeded"
AckSafety == acked => task = "succeeded"

=============================================================================
