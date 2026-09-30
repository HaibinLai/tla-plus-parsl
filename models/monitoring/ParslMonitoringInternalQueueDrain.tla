--------------------------- MODULE ParslMonitoringInternalQueueDrain ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Database-manager shutdown drain with an unreliable empty observation.
 *
 * The current loop uses queue.empty() in its stop condition.  If shutdown is
 * set while a pending internal message is present but empty() reports true,
 * the loop exits without processing that message.  The fixed branch drains
 * the known message before terminating.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES killSet, queueHasMessage, loopState, processed
vars == <<killSet, queueHasMessage, loopState, processed>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ killSet = TRUE
    /\ queueHasMessage = TRUE
    /\ loopState = "running"
    /\ processed = FALSE

ShutdownCheck ==
    /\ loopState = "running"
    /\ killSet
    /\ queueHasMessage
    /\ IF USE_FIXED
          THEN /\ processed' = TRUE
               /\ queueHasMessage' = FALSE
               /\ loopState' = "exited"
          ELSE /\ processed' = FALSE
               /\ queueHasMessage' = TRUE
               /\ loopState' = "exited"
    /\ UNCHANGED killSet

Next == ShutdownCheck \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ killSet \in BOOLEAN
    /\ queueHasMessage \in BOOLEAN
    /\ loopState \in {"running", "exited"}
    /\ processed \in BOOLEAN

ShutdownDrain == loopState = "exited" => processed

=============================================================================
