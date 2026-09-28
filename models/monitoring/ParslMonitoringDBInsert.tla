--------------------------- MODULE ParslMonitoringDBInsert ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Concrete monitoring DB insert boundary.
 *
 * STATUS rows use (task_id, run_id, status_name, timestamp) as a primary key.
 * A duplicate event therefore raises a non-OperationalError in SQLAlchemy.
 * The current DatabaseManager catches that exception, rolls back, and returns;
 * this model makes the resulting loss observable.  The fixed configuration
 * represents an idempotent duplicate path (ignore an already stored row).
 ***************************************************************************)

CONSTANTS DUPLICATE_EVENT, USE_FIXED

EventStates == {"queued", "writing", "stored", "dropped"}
DbErrors == {"none", "integrity"}

VARIABLES eventState, dbRows, dbError
vars == <<eventState, dbRows, dbError>>

Init ==
    /\ DUPLICATE_EVENT \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ eventState = "queued"
    /\ dbRows = IF DUPLICATE_EVENT THEN 1 ELSE 0
    /\ dbError = "none"

BeginInsert ==
    /\ eventState = "queued"
    /\ eventState' = "writing"
    /\ UNCHANGED <<dbRows, dbError>>

InsertRow ==
    /\ eventState = "writing"
    /\ ~DUPLICATE_EVENT
    /\ eventState' = "stored"
    /\ dbRows' = dbRows + 1
    /\ dbError' = "none"

DuplicateRejected ==
    /\ eventState = "writing"
    /\ DUPLICATE_EVENT
    /\ ~USE_FIXED
    /\ eventState' = "dropped"
    /\ dbError' = "integrity"
    /\ UNCHANGED dbRows

DuplicateIgnored ==
    /\ eventState = "writing"
    /\ DUPLICATE_EVENT
    /\ USE_FIXED
    /\ eventState' = "stored"
    /\ dbError' = "none"
    /\ UNCHANGED dbRows

Next ==
    \/ BeginInsert
    \/ InsertRow
    \/ DuplicateRejected
    \/ DuplicateIgnored
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ eventState \in EventStates
    /\ dbRows \in 0..1
    /\ dbError \in DbErrors

DuplicatePersistence ==
    DUPLICATE_EVENT => eventState # "dropped"

StoredRowCount ==
    eventState = "stored" => dbRows = 1

ErrorMatchesDrop ==
    dbError = "integrity" <=> eventState = "dropped"

=============================================================================
