--------------------------- MODULE ParslMonitoringExternalQueueEmptyRace ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Monitoring resource/log migration during shutdown.
 *
 * The migration loop uses Queue.empty() in its stop condition.  A stale
 * empty observation can report an external queue as empty even though a
 * message is still available.  The current branch exits and strands it;
 * USE_FIXED keeps draining until queue closure is observed.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES killSet, queueMessages, emptyObservation, workerState, migrated
vars == <<killSet, queueMessages, emptyObservation, workerState, migrated>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ killSet = TRUE
    /\ queueMessages = 1
    /\ emptyObservation = TRUE
    /\ workerState = "running"
    /\ migrated = 0

ObserveEmpty ==
    /\ killSet
    /\ queueMessages > 0
    /\ emptyObservation = FALSE
    /\ emptyObservation' = TRUE
    /\ UNCHANGED <<killSet, queueMessages, workerState, migrated>>

ExitOnEmpty ==
    /\ killSet
    /\ emptyObservation
    /\ IF USE_FIXED
          THEN /\ workerState' = "running"
               /\ UNCHANGED <<queueMessages, migrated>>
          ELSE /\ workerState' = "stopped"
               /\ UNCHANGED <<queueMessages, migrated>>
    /\ UNCHANGED <<killSet, emptyObservation>>

MigrateOne ==
    /\ workerState = "running"
    /\ queueMessages > 0
    /\ queueMessages' = queueMessages - 1
    /\ migrated' = migrated + 1
    /\ emptyObservation' = FALSE
    /\ UNCHANGED <<killSet, workerState>>

Next == ObserveEmpty \/ ExitOnEmpty \/ MigrateOne \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ killSet \in BOOLEAN
    /\ queueMessages \in 0..1
    /\ emptyObservation \in BOOLEAN
    /\ workerState \in {"running", "stopped"}
    /\ migrated \in 0..1

NoMessageLoss ==
    workerState = "stopped" => queueMessages = 0

=============================================================================
