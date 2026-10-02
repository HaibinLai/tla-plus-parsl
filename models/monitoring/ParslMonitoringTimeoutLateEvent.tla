--------------------------- MODULE ParslMonitoringTimeoutLateEvent ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Timeout status delivery to the monitoring database.
 *
 * A logical task has already timed out when an old successful completion emits
 * a status event.  Database writes may also retry after a transient failure.
 * The Current writer accepts the stale success and makes the database disagree
 * with the terminal Future; the Fixed writer applies only an event matching the
 * current logical terminal state.
 ***************************************************************************)

CONSTANTS MAX_DB_FAILURES, USE_FIXED

LogicalStates == {"running", "timed_out", "succeeded"}
DBStates == {"none", "timed_out", "succeeded"}
QueueStates == {"none", "queued", "retry"}

VARIABLES logicalState, futureState, queuedStatus, queueState, dbStatus,
          dbFailures, staleIgnored
vars == <<logicalState, futureState, queuedStatus, queueState, dbStatus,
           dbFailures, staleIgnored>>

Init ==
    /\ MAX_DB_FAILURES >= 0
    /\ USE_FIXED \in BOOLEAN
    /\ logicalState = "running"
    /\ futureState = "running"
    /\ queuedStatus = "none"
    /\ queueState = "none"
    /\ dbStatus = "none"
    /\ dbFailures = 0
    /\ staleIgnored = FALSE

TimeoutTask ==
    /\ logicalState = "running"
    /\ logicalState' = "timed_out"
    /\ futureState' = "timed_out"
    /\ queuedStatus' = "timed_out"
    /\ queueState' = "queued"
    /\ UNCHANGED <<dbStatus, dbFailures, staleIgnored>>

EmitLateSuccess ==
    /\ logicalState = "timed_out"
    /\ queueState \in {"queued", "retry"}
    /\ queuedStatus' = "succeeded"
    /\ UNCHANGED <<logicalState, futureState, queueState, dbStatus,
                    dbFailures, staleIgnored>>

TransientDBFailure ==
    /\ queueState = "queued"
    /\ dbFailures < MAX_DB_FAILURES
    /\ dbFailures' = dbFailures + 1
    /\ queueState' = "retry"
    /\ UNCHANGED <<logicalState, futureState, queuedStatus, dbStatus,
                    staleIgnored>>

WriteEvent ==
    /\ queueState \in {"queued", "retry"}
    /\ IF USE_FIXED /\ queuedStatus # IF logicalState = "timed_out"
                              THEN "timed_out" ELSE "succeeded"
          THEN /\ staleIgnored' = TRUE
               /\ queueState' = "none"
               /\ UNCHANGED dbStatus
          ELSE /\ dbStatus' = queuedStatus
               /\ queueState' = "none"
               /\ UNCHANGED staleIgnored
    /\ UNCHANGED <<logicalState, futureState, queuedStatus, dbFailures>>

Next ==
    \/ TimeoutTask
    \/ EmitLateSuccess
    \/ TransientDBFailure
    \/ WriteEvent
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ logicalState \in LogicalStates
    /\ futureState \in LogicalStates
    /\ queuedStatus \in DBStates \cup {"none"}
    /\ queueState \in QueueStates
    /\ dbStatus \in DBStates
    /\ dbFailures \in 0..MAX_DB_FAILURES
    /\ staleIgnored \in BOOLEAN

TimeoutDatabaseSafety ==
    logicalState = "timed_out" =>
        /\ futureState = "timed_out"
        /\ dbStatus # "succeeded"

DatabaseLogicalConsistency ==
    dbStatus \in {"timed_out", "succeeded"} =>
        dbStatus = IF logicalState = "timed_out" THEN "timed_out" ELSE "succeeded"

RetryBound == dbFailures <= MAX_DB_FAILURES

=============================================================================
