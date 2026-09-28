--------------------------- MODULE ParslHtexManagerMessage ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Manager-to-interchange message decoding.  The interchange ignores a
 * malformed multipart/pickle message without changing manager state.  A
 * valid heartbeat updates the timestamp and emits the heartbeat reply.
 *************************************************************************** *)

CONSTANT MESSAGE_KIND

Kinds == {"malformed", "heartbeat"}
Phases == {"received", "ignored", "decoded", "updated", "replied"}
VARIABLES phase, heartbeatTime, replySent
vars == <<phase, heartbeatTime, replySent>>

Init ==
    /\ MESSAGE_KIND \in Kinds
    /\ phase = "received"
    /\ heartbeatTime = 0
    /\ replySent = FALSE

DecodeMalformed ==
    /\ phase = "received"
    /\ MESSAGE_KIND = "malformed"
    /\ phase' = "ignored"
    /\ UNCHANGED <<heartbeatTime, replySent>>

DecodeHeartbeat ==
    /\ phase = "received"
    /\ MESSAGE_KIND = "heartbeat"
    /\ phase' = "decoded"
    /\ UNCHANGED <<heartbeatTime, replySent>>

UpdateHeartbeat ==
    /\ phase = "decoded"
    /\ phase' = "updated"
    /\ heartbeatTime' = 1
    /\ UNCHANGED replySent

ReplyHeartbeat ==
    /\ phase = "updated"
    /\ phase' = "replied"
    /\ replySent' = TRUE
    /\ UNCHANGED heartbeatTime

Next ==
    \/ DecodeMalformed
    \/ DecodeHeartbeat
    \/ UpdateHeartbeat
    \/ ReplyHeartbeat
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ phase \in Phases
    /\ heartbeatTime \in 0..1
    /\ replySent \in BOOLEAN

MalformedIsolation ==
    MESSAGE_KIND = "malformed" =>
        /\ phase \in {"received", "ignored"}
        /\ heartbeatTime = 0
        /\ ~replySent

HeartbeatReplySafety ==
    phase = "replied" => heartbeatTime = 1 /\ replySent

=============================================================================
