--------------------------- MODULE ParslMonitoringLastMessageRace ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Worker last-message ordering at DatabaseManager._db_mgmt_loop.
 *
 * The current implementation defers a worker first message until TASK_INFO
 * creates the TRY row, but sends a last message directly to STATUS.  If the
 * last message wins the queue race, a status row can therefore exist before
 * its try row.  USE_FIXED represents applying the same defer/replay rule to
 * last messages.
 ***************************************************************************)

CONSTANT USE_FIXED
MAX_STATUS_ROWS == 2

VARIABLES tryInserted, pendingLast, statusRows
vars == <<tryInserted, pendingLast, statusRows>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ tryInserted = FALSE
    /\ pendingLast = FALSE
    /\ statusRows = 0

ReceiveLastBeforeTry ==
    /\ ~tryInserted
    /\ IF USE_FIXED
          THEN /\ pendingLast' = TRUE
               /\ statusRows' = statusRows
          ELSE /\ pendingLast' = FALSE
               /\ statusRows' = statusRows + 1
    /\ UNCHANGED tryInserted

InsertTry ==
    /\ ~tryInserted
    /\ tryInserted' = TRUE
    /\ statusRows' = statusRows + IF pendingLast THEN 1 ELSE 0
    /\ pendingLast' = FALSE

ReceiveLastAfterTry ==
    /\ tryInserted
    /\ statusRows < MAX_STATUS_ROWS
    /\ statusRows' = statusRows + 1
    /\ UNCHANGED <<tryInserted, pendingLast>>

Next ==
    \/ ReceiveLastBeforeTry
    \/ InsertTry
    \/ ReceiveLastAfterTry
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ tryInserted \in BOOLEAN
    /\ pendingLast \in BOOLEAN
    /\ statusRows \in 0..MAX_STATUS_ROWS

ForeignKeySafety == statusRows > 0 => tryInserted

ReplaySafety == pendingLast => ~tryInserted

=============================================================================
