--------------------------- MODULE ParslMonitoringWorkerTryAtomicity ---------------------------
EXTENDS Naturals

(***************************************************************************
 * A worker first message is handled by two database operations: STATUS is
 * inserted and TRY is updated to running.  If the TRY update fails after the
 * STATUS commit, the current DatabaseManager leaves a partial cross-table
 * state.  The fixed branch rolls back/retains the event until both writes can
 * be completed together.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES statusPresent, tryRunning, tryFailure, eventRetained
vars == <<statusPresent, tryRunning, tryFailure, eventRetained>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ statusPresent = FALSE
    /\ tryRunning = FALSE
    /\ tryFailure = FALSE
    /\ eventRetained = FALSE

InsertStatus ==
    /\ ~statusPresent
    /\ statusPresent' = TRUE
    /\ eventRetained' = USE_FIXED
    /\ UNCHANGED <<tryRunning, tryFailure>>

FailTryUpdate ==
    /\ statusPresent
    /\ ~tryRunning
    /\ tryFailure' = TRUE
    /\ IF USE_FIXED
          THEN /\ statusPresent' = FALSE
               /\ eventRetained' = TRUE
          ELSE /\ statusPresent' = TRUE
               /\ eventRetained' = FALSE
    /\ UNCHANGED tryRunning

RetryRetainedEvent ==
    /\ USE_FIXED
    /\ eventRetained
    /\ statusPresent' = TRUE
    /\ tryRunning' = TRUE
    /\ eventRetained' = FALSE
    /\ UNCHANGED tryFailure

Next ==
    \/ InsertStatus
    \/ FailTryUpdate
    \/ RetryRetainedEvent
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ statusPresent \in BOOLEAN
    /\ tryRunning \in BOOLEAN
    /\ tryFailure \in BOOLEAN
    /\ eventRetained \in BOOLEAN

CrossTableAtomicity ==
    statusPresent => tryRunning \/ eventRetained

=============================================================================
