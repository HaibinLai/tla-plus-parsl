--------------------------- MODULE ParslHtexWatchdogResultRace ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Result publication versus HTEX worker watchdog.
 *
 * A worker publishes a result before it removes its worker_id from
 * `_tasks_in_progress`. If the physical worker dies in that interval, the
 * watchdog sees the stale mapping and publishes a second WorkerLost result
 * for the same logical task. USE_FIXED represents checking result
 * publication before synthesizing WorkerLost.
 ***************************************************************************)

CONSTANT USE_FIXED

WorkerStates == {"alive", "dead", "restarted"}
MapStates == {"mapped", "cleared"}
ResultStates == {"none", "queued", "worker_lost_queued", "duplicate_queued"}

VARIABLES workerState, mapState, resultState
vars == <<workerState, mapState, resultState>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ workerState = "alive"
    /\ mapState = "mapped"
    /\ resultState = "none"

PublishResult ==
    /\ workerState = "alive"
    /\ mapState = "mapped"
    /\ resultState = "none"
    /\ resultState' = "queued"
    /\ UNCHANGED <<workerState, mapState>>

ClearTaskMap ==
    /\ workerState = "alive"
    /\ mapState = "mapped"
    /\ resultState = "queued"
    /\ mapState' = "cleared"
    /\ UNCHANGED <<workerState, resultState>>

WorkerDies ==
    /\ workerState = "alive"
    /\ workerState' = "dead"
    /\ UNCHANGED <<mapState, resultState>>

WatchdogRecovers ==
    /\ workerState = "dead"
    /\ mapState = "mapped"
    /\ workerState' = "restarted"
    /\ resultState' = IF resultState = "none"
                      THEN "worker_lost_queued"
                      ELSE IF USE_FIXED THEN resultState ELSE "duplicate_queued"
    /\ UNCHANGED mapState

WatchdogRecoversAfterClear ==
    /\ workerState = "dead"
    /\ mapState = "cleared"
    /\ workerState' = "restarted"
    /\ UNCHANGED <<mapState, resultState>>

Next ==
    \/ PublishResult
    \/ ClearTaskMap
    \/ WorkerDies
    \/ WatchdogRecovers
    \/ WatchdogRecoversAfterClear
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ workerState \in WorkerStates
    /\ mapState \in MapStates
    /\ resultState \in ResultStates

NoDuplicateResult ==
    resultState # "duplicate_queued"

ResultStateSafety ==
    resultState = "duplicate_queued" => workerState = "restarted"

=============================================================================
