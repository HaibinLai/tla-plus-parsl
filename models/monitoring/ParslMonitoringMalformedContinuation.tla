--------------------------- MODULE ParslMonitoringMalformedContinuation ---------------------------
EXTENDS Naturals, Sequences

(***************************************************************************
 * A small continuation model for DatabaseManager's worker-task batch loop.
 *
 * The batch contains one malformed worker message followed by a valid last
 * message.  The current loop raises while walking the batch, so the valid
 * message is never persisted.  The fixed branch discards the malformed
 * record and continues with the remaining records.
 ***************************************************************************)

CONSTANT USE_FIXED
VARIABLES cursor, workerState, malformedDiscarded, validPersisted
vars == <<cursor, workerState, malformedDiscarded, validPersisted>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ cursor = 1
    /\ workerState = "alive"
    /\ malformedDiscarded = FALSE
    /\ validPersisted = FALSE

ProcessMalformed ==
    /\ cursor = 1
    /\ workerState = "alive"
    /\ IF USE_FIXED
          THEN /\ cursor' = 2
               /\ malformedDiscarded' = TRUE
               /\ UNCHANGED <<workerState, validPersisted>>
          ELSE /\ workerState' = "crashed"
               /\ UNCHANGED <<cursor, malformedDiscarded, validPersisted>>

ProcessValid ==
    /\ cursor = 2
    /\ workerState = "alive"
    /\ cursor' = 3
    /\ validPersisted' = TRUE
    /\ UNCHANGED <<workerState, malformedDiscarded>>

Next ==
    \/ ProcessMalformed
    \/ ProcessValid
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ cursor \in 1..3
    /\ workerState \in {"alive", "crashed"}
    /\ malformedDiscarded \in BOOLEAN
    /\ validPersisted \in BOOLEAN

WorkerSurvives == workerState = "alive"

ValidBatchContinuation ==
    cursor = 3 => validPersisted

=============================================================================
