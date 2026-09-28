--------------------------- MODULE ParslMonitoringBatch ---------------------------
EXTENDS Naturals

(***************************************************************************
 * DatabaseManager._get_messages_in_batch checks the elapsed-time boundary
 * before reading the queue.  With batching_interval=0, the current path can
 * return an empty batch even when a message is waiting; the FIXED branch
 * consumes at least one available message before applying the interval.
 *************************************************************************** *)

CONSTANTS ZERO_INTERVAL, MESSAGE_AVAILABLE, USE_FIXED

States == {"ready", "done"}
VARIABLES state, collected, queueStillHasMessage
vars == <<state, collected, queueStillHasMessage>>

Init ==
    /\ ZERO_INTERVAL \in BOOLEAN
    /\ MESSAGE_AVAILABLE \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ state = "ready"
    /\ collected = FALSE
    /\ queueStillHasMessage = MESSAGE_AVAILABLE

Batch ==
    /\ state = "ready"
    /\ state' = "done"
    /\ IF MESSAGE_AVAILABLE /\ (~ZERO_INTERVAL \/ USE_FIXED)
          THEN /\ collected' = TRUE
               /\ queueStillHasMessage' = FALSE
          ELSE /\ UNCHANGED <<collected, queueStillHasMessage>>

Next ==
    \/ Batch
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in States
    /\ collected \in BOOLEAN
    /\ queueStillHasMessage \in BOOLEAN

AvailableBatchSafety ==
    MESSAGE_AVAILABLE /\ state = "done" => collected

=============================================================================
