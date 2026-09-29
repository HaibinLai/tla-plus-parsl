--------------------------- MODULE ParslWorkerPoolControlFrame ---------------------------
EXTENDS Naturals

(***************************************************************************
 * HTEX process-worker-pool control frames.
 *
 * Manager.heartbeat_to_incoming and drain_to_incoming send pickled control
 * dictionaries.  The receive loop currently calls pickle.loads directly on
 * every incoming frame.  A malformed frame therefore reaches the manager's
 * receive thread as an uncaught decode failure.  The fixed branch validates
 * the frame before applying its control action and discards malformed input.
 ***************************************************************************)

CONSTANT USE_FIXED

FrameKinds == {"heartbeat", "drain", "malformed", "none"}
Phases == {"idle", "sent", "decoded", "discarded", "crashed"}

VARIABLES phase, frameKind, decodedKind
vars == <<phase, frameKind, decodedKind>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ phase = "idle"
    /\ frameKind = "none"
    /\ decodedKind = "none"

SendHeartbeat ==
    /\ phase = "idle"
    /\ phase' = "sent"
    /\ frameKind' = "heartbeat"
    /\ UNCHANGED decodedKind

SendDrain ==
    /\ phase = "idle"
    /\ phase' = "sent"
    /\ frameKind' = "drain"
    /\ UNCHANGED decodedKind

SendMalformed ==
    /\ phase = "idle"
    /\ phase' = "sent"
    /\ frameKind' = "malformed"
    /\ UNCHANGED decodedKind

DecodeFrame ==
    /\ phase = "sent"
    /\ IF frameKind = "malformed"
          THEN IF USE_FIXED
                  THEN /\ phase' = "discarded"
                       /\ decodedKind' = "none"
                  ELSE /\ phase' = "crashed"
                       /\ decodedKind' = "none"
          ELSE /\ phase' = "decoded"
               /\ decodedKind' = frameKind
    /\ UNCHANGED frameKind

Reset ==
    /\ phase \in {"decoded", "discarded", "crashed"}
    /\ phase' = "idle"
    /\ frameKind' = "none"
    /\ decodedKind' = "none"

Next ==
    \/ SendHeartbeat
    \/ SendDrain
    \/ SendMalformed
    \/ DecodeFrame
    \/ Reset
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ phase \in Phases
    /\ frameKind \in FrameKinds
    /\ decodedKind \in FrameKinds

MalformedDecodeSafety ==
    phase = "crashed" => frameKind # "malformed"

ControlDecodeSafety ==
    phase = "decoded" => decodedKind \in {"heartbeat", "drain"}

=============================================================================
