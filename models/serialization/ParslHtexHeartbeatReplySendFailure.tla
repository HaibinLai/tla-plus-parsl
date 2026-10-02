--------------------------- MODULE ParslHtexHeartbeatReplySendFailure ---------------------------
EXTENDS Naturals

(***************************************************************************
 * HTEX interchange heartbeat ACK send failure.
 *
 * Interchange.process_manager_socket_message updates the manager heartbeat
 * timestamp and then sends PKL_HEARTBEAT_CODE.  The Current branch lets a
 * failed ACK send escape the main loop; the Fixed branch isolates the broken
 * peer while preserving the heartbeat state and loop liveness.
 ***************************************************************************)

CONSTANT USE_FIXED
VARIABLES interchangeState, heartbeatState, laterWorkState
vars == <<interchangeState, heartbeatState, laterWorkState>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ interchangeState = "alive"
    /\ heartbeatState = "ack_pending"
    /\ laterWorkState = "pending"

HeartbeatAckSendFailure ==
    /\ interchangeState = "alive"
    /\ heartbeatState = "ack_pending"
    /\ IF USE_FIXED
          THEN /\ interchangeState' = "alive"
               /\ heartbeatState' = "ack_failed"
               /\ UNCHANGED laterWorkState
          ELSE /\ interchangeState' = "crashed"
               /\ UNCHANGED <<heartbeatState, laterWorkState>>

ProcessLaterWork ==
    /\ interchangeState = "alive"
    /\ heartbeatState = "ack_failed"
    /\ laterWorkState' = "processed"
    /\ UNCHANGED <<interchangeState, heartbeatState>>

Next ==
    \/ HeartbeatAckSendFailure
    \/ ProcessLaterWork
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ interchangeState \in {"alive", "crashed"}
    /\ heartbeatState \in {"ack_pending", "ack_failed"}
    /\ laterWorkState \in {"pending", "processed"}

InterchangeSurvives == interchangeState = "alive"

LaterWorkAvailable ==
    laterWorkState = "processed" => interchangeState = "alive"

=============================================================================
