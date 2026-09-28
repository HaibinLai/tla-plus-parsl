--------------------------- MODULE ParslMonitoringDeferred ---------------------------
EXTENDS Naturals, FiniteSets

(***************************************************************************
 * Monitoring DB deferred worker-task messages.
 *
 * DatabaseManager defers a worker's first resource/status message when the
 * corresponding TASK_INFO/TRY row has not arrived yet.  Once that row is
 * inserted, the deferred message is replayed.  A second first-message for
 * the same task/try replaces and discards the one-entry deferred record.
 ***************************************************************************)

MAX_DISCARDS == 1
MAX_STATUS_ROWS == 2

VARIABLES taskInserted, tryInserted, deferredFirst, statusRows, discardCount,
          workflowClosed
vars == <<taskInserted, tryInserted, deferredFirst, statusRows, discardCount,
           workflowClosed>>

Init ==
    /\ taskInserted = FALSE
    /\ tryInserted = FALSE
    /\ deferredFirst = FALSE
    /\ statusRows = 0
    /\ discardCount = 0
    /\ workflowClosed = FALSE

ReceiveFirstBeforeTry ==
    /\ ~workflowClosed
    /\ ~tryInserted
    /\ ~deferredFirst
    /\ deferredFirst' = TRUE
    /\ UNCHANGED <<taskInserted, tryInserted, statusRows,
                    discardCount, workflowClosed>>

ReceiveDuplicateFirstBeforeTry ==
    /\ ~workflowClosed
    /\ ~tryInserted
    /\ deferredFirst
    /\ discardCount < MAX_DISCARDS
    /\ discardCount' = discardCount + 1
    /\ UNCHANGED <<taskInserted, tryInserted, deferredFirst,
                    statusRows, workflowClosed>>

InsertTaskAndTry ==
    /\ ~workflowClosed
    /\ ~tryInserted
    /\ taskInserted' = TRUE
    /\ tryInserted' = TRUE
    /\ deferredFirst' = FALSE
    /\ statusRows' = IF deferredFirst THEN statusRows + 1 ELSE statusRows
    /\ UNCHANGED <<discardCount, workflowClosed>>

ReceiveFirstAfterTry ==
    /\ ~workflowClosed
    /\ tryInserted
    /\ statusRows < MAX_STATUS_ROWS
    /\ statusRows' = statusRows + 1
    /\ UNCHANGED <<taskInserted, tryInserted, deferredFirst,
                    discardCount, workflowClosed>>

ReceiveLastAfterTry ==
    /\ ~workflowClosed
    /\ tryInserted
    /\ statusRows < MAX_STATUS_ROWS
    /\ statusRows' = statusRows + 1
    /\ UNCHANGED <<taskInserted, tryInserted, deferredFirst,
                    discardCount, workflowClosed>>

CloseWorkflow ==
    /\ ~workflowClosed
    /\ workflowClosed' = TRUE
    /\ UNCHANGED <<taskInserted, tryInserted, deferredFirst,
                    statusRows, discardCount>>

Next ==
    \/ ReceiveFirstBeforeTry
    \/ ReceiveDuplicateFirstBeforeTry
    \/ InsertTaskAndTry
    \/ ReceiveFirstAfterTry
    \/ ReceiveLastAfterTry
    \/ CloseWorkflow
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ taskInserted \in BOOLEAN
    /\ tryInserted \in BOOLEAN
    /\ deferredFirst \in BOOLEAN
    /\ statusRows \in 0..MAX_STATUS_ROWS
    /\ discardCount \in 0..MAX_DISCARDS
    /\ workflowClosed \in BOOLEAN

ForeignKeySafety ==
    statusRows > 0 => tryInserted

DeferredGateSafety ==
    deferredFirst => ~tryInserted

ReplaySafety ==
    tryInserted => ~deferredFirst

DiscardBoundSafety ==
    discardCount <= MAX_DISCARDS

=============================================================================
