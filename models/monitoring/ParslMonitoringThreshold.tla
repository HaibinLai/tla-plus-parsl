--------------------------- MODULE ParslMonitoringThreshold ---------------------------
EXTENDS Naturals

(***************************************************************************
 * DatabaseManager._get_messages_in_batch with a zero batching threshold.
 *
 * The current loop checks ``len(messages) >= batching_threshold`` before
 * reading the queue.  With threshold zero this is true for an empty batch,
 * so an available monitoring event is left queued.  USE_FIXED models a
 * minimum-one-message guard before applying the threshold.
 ***************************************************************************)

CONSTANTS ZERO_THRESHOLD, MESSAGE_AVAILABLE, USE_FIXED
States == {"ready", "done"}

VARIABLES state, collected, queueStillHasMessage
vars == <<state, collected, queueStillHasMessage>>

Init ==
    /\ ZERO_THRESHOLD \in BOOLEAN
    /\ MESSAGE_AVAILABLE \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ state = "ready"
    /\ collected = FALSE
    /\ queueStillHasMessage = MESSAGE_AVAILABLE

Batch ==
    /\ state = "ready"
    /\ state' = "done"
    /\ IF MESSAGE_AVAILABLE /\ (~ZERO_THRESHOLD \/ USE_FIXED)
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
