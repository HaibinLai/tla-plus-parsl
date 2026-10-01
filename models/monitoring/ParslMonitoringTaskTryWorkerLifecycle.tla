--------------------------- MODULE ParslMonitoringTaskTryWorkerLifecycle ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Monitoring database cross-table lifecycle.
 *
 * A worker-first message can arrive before TASK/TRY rows exist.  The
 * DatabaseManager defers it and replays it after TASK_INFO inserts those
 * rows.  Replay must publish the STATUS row and the TRY running update as
 * one logical observation.  The Current branch can expose either half when
 * one write fails; the Fixed branch retains the event for retry and never
 * publishes a partial cross-table state.
 ***************************************************************************)

CONSTANTS USE_FIXED, FAIL_STEP

Steps == {"none", "status", "try"}
Phases == {"open", "worker-deferred", "rows-created", "replayed"}

VARIABLES phase, taskRow, tryRow, statusRow, tryRunning, workerPending
vars == <<phase, taskRow, tryRow, statusRow, tryRunning, workerPending>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ FAIL_STEP \in Steps
    /\ phase = "open"
    /\ taskRow = FALSE
    /\ tryRow = FALSE
    /\ statusRow = FALSE
    /\ tryRunning = FALSE
    /\ workerPending = FALSE

ReceiveWorkerFirst ==
    /\ phase = "open"
    /\ workerPending = FALSE
    /\ phase' = "worker-deferred"
    /\ workerPending' = TRUE
    /\ UNCHANGED <<taskRow, tryRow, statusRow, tryRunning>>

InsertTaskTry ==
    /\ phase = "worker-deferred"
    /\ taskRow = FALSE
    /\ tryRow = FALSE
    /\ phase' = "rows-created"
    /\ taskRow' = TRUE
    /\ tryRow' = TRUE
    /\ UNCHANGED <<statusRow, tryRunning, workerPending>>

ReplayWorker ==
    /\ phase = "rows-created"
    /\ workerPending
    /\ IF USE_FIXED
          THEN IF FAIL_STEP = "none"
               THEN /\ statusRow' = TRUE
                    /\ tryRunning' = TRUE
                    /\ workerPending' = FALSE
                    /\ phase' = "replayed"
               ELSE /\ UNCHANGED <<statusRow, tryRunning, workerPending, phase>>
          ELSE IF FAIL_STEP = "status"
               THEN /\ statusRow' = FALSE
                    /\ tryRunning' = TRUE
                    /\ workerPending' = FALSE
                    /\ phase' = "replayed"
               ELSE IF FAIL_STEP = "try"
                    THEN /\ statusRow' = TRUE
                         /\ tryRunning' = FALSE
                         /\ workerPending' = FALSE
                         /\ phase' = "replayed"
                    ELSE /\ statusRow' = TRUE
                         /\ tryRunning' = TRUE
                         /\ workerPending' = FALSE
                         /\ phase' = "replayed"
    /\ UNCHANGED <<taskRow, tryRow>>

Next ==
    \/ ReceiveWorkerFirst
    \/ InsertTaskTry
    \/ ReplayWorker
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ FAIL_STEP \in Steps
    /\ phase \in Phases
    /\ taskRow \in BOOLEAN
    /\ tryRow \in BOOLEAN
    /\ statusRow \in BOOLEAN
    /\ tryRunning \in BOOLEAN
    /\ workerPending \in BOOLEAN

CrossTableConsistency ==
    tryRunning = statusRow

DeferredEventSafety ==
    USE_FIXED => (workerPending \/ (statusRow /\ tryRunning) \/ phase = "open")

=============================================================================
