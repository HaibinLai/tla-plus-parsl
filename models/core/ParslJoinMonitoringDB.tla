------------------------- MODULE ParslJoinMonitoringDB -------------------------
EXTENDS Naturals, FiniteSets

(***************************************************************************
 * Join terminal status and monitoring database persistence.
 *
 * The outer join becomes terminal before its status is queued and written to
 * the monitoring database.  A transient write can be retried.  A duplicate
 * row may already exist when the writer runs; the fixed branch treats that
 * write idempotently, while the Current branch loses the terminal status.
 *************************************************************************** *)

CONSTANT USE_FIXED, MAX_DB_FAILURES
OuterStates == {"joining", "succeeded"}
InnerStates == {"pending", "done"}
MonitorStates == {"none", "queued", "persisted", "failed"}
DBStatuses == {"none", "succeeded"}

VARIABLES outer, inner, monitor, dbStatus, dbFailures, duplicateRow,
          transientFailure
vars == <<outer, inner, monitor, dbStatus, dbFailures, duplicateRow,
           transientFailure>>

Init ==
    /\ MAX_DB_FAILURES >= 0
    /\ outer = "joining"
    /\ inner = "pending"
    /\ monitor = "none"
    /\ dbStatus = "none"
    /\ dbFailures = 0
    /\ duplicateRow = FALSE
    /\ transientFailure = FALSE

CompleteInner ==
    /\ inner = "pending"
    /\ inner' = "done"
    /\ UNCHANGED <<outer, monitor, dbStatus, dbFailures,
                    duplicateRow, transientFailure>>

FinalizeJoin ==
    /\ outer = "joining"
    /\ inner = "done"
    /\ outer' = "succeeded"
    /\ UNCHANGED <<inner, monitor, dbStatus, dbFailures,
                    duplicateRow, transientFailure>>

QueueStatus ==
    /\ outer = "succeeded"
    /\ monitor = "none"
    /\ monitor' = "queued"
    /\ UNCHANGED <<outer, inner, dbStatus, dbFailures,
                    duplicateRow, transientFailure>>

InjectDuplicateRow ==
    /\ monitor = "queued"
    /\ duplicateRow' = TRUE
    /\ UNCHANGED <<outer, inner, monitor, dbStatus, dbFailures,
                    transientFailure>>

InjectTransientFailure ==
    /\ monitor = "queued"
    /\ dbFailures < MAX_DB_FAILURES
    /\ transientFailure' = TRUE
    /\ dbFailures' = dbFailures + 1
    /\ UNCHANGED <<outer, inner, monitor, dbStatus, duplicateRow>>

WriteStatus ==
    /\ monitor = "queued"
    /\ IF transientFailure
          THEN /\ transientFailure' = FALSE
               /\ UNCHANGED <<monitor, dbStatus, duplicateRow>>
          ELSE IF duplicateRow /\ ~USE_FIXED
                    THEN /\ monitor' = "failed"
                         /\ UNCHANGED <<dbStatus, duplicateRow, transientFailure>>
                    ELSE /\ monitor' = "persisted"
                         /\ dbStatus' = "succeeded"
                         /\ duplicateRow' = FALSE
                         /\ transientFailure' = FALSE
    /\ UNCHANGED <<outer, inner, dbFailures>>

Next ==
    \/ CompleteInner \/ FinalizeJoin \/ QueueStatus
    \/ InjectDuplicateRow \/ InjectTransientFailure \/ WriteStatus
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ outer \in OuterStates
    /\ inner \in InnerStates
    /\ monitor \in MonitorStates
    /\ dbStatus \in DBStatuses
    /\ dbFailures \in 0..MAX_DB_FAILURES
    /\ duplicateRow \in BOOLEAN
    /\ transientFailure \in BOOLEAN

TerminalStateSafety == outer = "succeeded" => inner = "done"
MonitoringConsistency == monitor = "persisted" => dbStatus = "succeeded"
TerminalStatusSafety == outer = "succeeded" => monitor # "failed"
DBRetryBound == dbFailures <= MAX_DB_FAILURES

=============================================================================
