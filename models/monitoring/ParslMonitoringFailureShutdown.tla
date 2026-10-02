------------------------ MODULE ParslMonitoringFailureShutdown ------------------------
EXTENDS Naturals

(***************************************************************************
 * Monitoring WORKFLOW-end persistence and shutdown.
 *
 * A close request queues a workflow-end update.  A permanent database error
 * can occur while the update is being written.  The Current branch marks the
 * workflow finished and stops without retaining a terminal database outcome;
 * the Fixed branch bounds retries and records either persistence or an explicit
 * dead-letter/aborted outcome before the loop terminates.
 ***************************************************************************)

CONSTANTS MAX_RETRIES, DB_FAIL, USE_FIXED

VARIABLES closeRequested, endQueued, endPersisted, endDropped,
          workflowEndFlag, loopStopped, retries

vars == <<closeRequested, endQueued, endPersisted, endDropped,
          workflowEndFlag, loopStopped, retries>>

Init ==
    /\ MAX_RETRIES >= 0
    /\ DB_FAIL \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ closeRequested = FALSE
    /\ endQueued = FALSE
    /\ endPersisted = FALSE
    /\ endDropped = FALSE
    /\ workflowEndFlag = FALSE
    /\ loopStopped = FALSE
    /\ retries = 0

Close ==
    /\ ~closeRequested
    /\ closeRequested' = TRUE
    /\ endQueued' = TRUE
    /\ UNCHANGED <<endPersisted, endDropped, workflowEndFlag,
                    loopStopped, retries>>

WriteEndSuccess ==
    /\ endQueued
    /\ ~DB_FAIL
    /\ endQueued' = FALSE
    /\ endPersisted' = TRUE
    /\ workflowEndFlag' = TRUE
    /\ loopStopped' = TRUE
    /\ UNCHANGED <<closeRequested, endDropped, retries>>

RetryEndFixed ==
    /\ endQueued
    /\ DB_FAIL
    /\ USE_FIXED
    /\ retries < MAX_RETRIES
    /\ retries' = retries + 1
    /\ UNCHANGED <<closeRequested, endQueued, endPersisted, endDropped,
                    workflowEndFlag, loopStopped>>

DropEndFixed ==
    /\ endQueued
    /\ DB_FAIL
    /\ USE_FIXED
    /\ retries = MAX_RETRIES
    /\ endQueued' = FALSE
    /\ endDropped' = TRUE
    /\ workflowEndFlag' = TRUE
    /\ loopStopped' = TRUE
    /\ UNCHANGED <<closeRequested, endPersisted, retries>>

DropEndCurrent ==
    /\ endQueued
    /\ DB_FAIL
    /\ ~USE_FIXED
    /\ endQueued' = FALSE
    /\ workflowEndFlag' = TRUE
    /\ loopStopped' = TRUE
    /\ UNCHANGED <<closeRequested, endPersisted, endDropped, retries>>

Shutdown ==
    /\ closeRequested
    /\ ~loopStopped
    /\ IF USE_FIXED THEN endPersisted \/ endDropped ELSE TRUE
    /\ loopStopped' = TRUE
    /\ UNCHANGED <<closeRequested, endQueued, endPersisted, endDropped,
                    workflowEndFlag, retries>>

Next ==
    \/ Close
    \/ WriteEndSuccess
    \/ RetryEndFixed
    \/ DropEndFixed
    \/ DropEndCurrent
    \/ Shutdown
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ closeRequested \in BOOLEAN
    /\ endQueued \in BOOLEAN
    /\ endPersisted \in BOOLEAN
    /\ endDropped \in BOOLEAN
    /\ workflowEndFlag \in BOOLEAN
    /\ loopStopped \in BOOLEAN
    /\ retries \in 0..MAX_RETRIES

TerminalOutcomeSafety ==
    loopStopped => endPersisted \/ endDropped

WorkflowMarkerSafety ==
    workflowEndFlag => endPersisted \/ endDropped

RetryBoundSafety == retries <= MAX_RETRIES

=============================================================================
CONSTANTS
    MAX_RETRIES = 1
    DB_FAIL = TRUE
    USE_FIXED = TRUE

SPECIFICATION Spec

INVARIANTS
    TypeOK
    TerminalOutcomeSafety
    WorkflowMarkerSafety
    RetryBoundSafety
