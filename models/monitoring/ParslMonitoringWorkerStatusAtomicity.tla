------------------------------ MODULE ParslMonitoringWorkerStatusAtomicity ------------------------------
EXTENDS Naturals

(***************************************************************************
 * A worker first message is handled by two database operations: STATUS is
 * inserted and TRY is updated to running.  The current DatabaseManager
 * swallows a STATUS write exception and still performs the TRY update.
 * USE_FIXED gates the TRY update on successful STATUS persistence.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES statusPresent, tryRunning, statusFailure
vars == <<statusPresent, tryRunning, statusFailure>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ statusPresent = FALSE
    /\ tryRunning = FALSE
    /\ statusFailure = FALSE

BeginWorkerMessage ==
    /\ ~statusPresent
    /\ ~tryRunning
    /\ statusFailure' = TRUE
    /\ statusPresent' = FALSE
    /\ UNCHANGED tryRunning

UpdateTryAfterStatusFailure ==
    /\ statusFailure
    /\ tryRunning' = IF USE_FIXED THEN FALSE ELSE TRUE
    /\ UNCHANGED <<statusPresent, statusFailure>>

RecoverStatus ==
    /\ statusFailure
    /\ statusPresent' = TRUE
    /\ statusFailure' = FALSE
    /\ UNCHANGED tryRunning

Next ==
    \/ BeginWorkerMessage
    \/ UpdateTryAfterStatusFailure
    \/ RecoverStatus
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ statusPresent \in BOOLEAN
    /\ tryRunning \in BOOLEAN
    /\ statusFailure \in BOOLEAN

CrossTableStatusSafety == tryRunning => statusPresent

=============================================================================
