--------------------------- MODULE ParslMonitoringShutdownRace ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Late producer race in DatabaseManager._migrate_logs_to_internal.
 *
 * The migration loop stops when kill_event is set and Queue.empty() is true.
 * A producer can enqueue after that observation, leaving a record stranded.
 * USE_FIXED represents waiting for producer closure before accepting the empty
 * queue as a shutdown boundary.
 ***************************************************************************)

CONSTANT USE_FIXED
MAX_MESSAGES == 1

States == {"running", "stopped"}

VARIABLES state, killSet, producerClosed, queueSize, enqueued, migrated
vars == <<state, killSet, producerClosed, queueSize, enqueued, migrated>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ state = "running"
    /\ killSet = FALSE
    /\ producerClosed = FALSE
    /\ queueSize = 0
    /\ enqueued = 0
    /\ migrated = 0

SignalClose ==
    /\ ~killSet
    /\ killSet' = TRUE
    /\ UNCHANGED <<state, producerClosed, queueSize, enqueued, migrated>>

ProducerEnqueue ==
    /\ ~producerClosed
    /\ state = "running" \/ ~USE_FIXED
    /\ enqueued < MAX_MESSAGES
    /\ queueSize' = queueSize + 1
    /\ enqueued' = enqueued + 1
    /\ UNCHANGED <<state, killSet, producerClosed, migrated>>

ProducerClose ==
    /\ ~producerClosed
    /\ producerClosed' = TRUE
    /\ UNCHANGED <<state, killSet, queueSize, enqueued, migrated>>

MigrateOne ==
    /\ state = "running"
    /\ queueSize > 0
    /\ queueSize' = queueSize - 1
    /\ migrated' = migrated + 1
    /\ UNCHANGED <<state, killSet, producerClosed, enqueued>>

ObserveEmptyAndStop ==
    /\ state = "running"
    /\ killSet
    /\ queueSize = 0
    /\ ~USE_FIXED \/ producerClosed
    /\ state' = "stopped"
    /\ UNCHANGED <<killSet, producerClosed, queueSize, enqueued, migrated>>

Next ==
    \/ SignalClose
    \/ ProducerEnqueue
    \/ ProducerClose
    \/ MigrateOne
    \/ ObserveEmptyAndStop
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ state \in States
    /\ killSet \in BOOLEAN
    /\ producerClosed \in BOOLEAN
    /\ queueSize \in 0..MAX_MESSAGES
    /\ enqueued \in 0..MAX_MESSAGES
    /\ migrated \in 0..MAX_MESSAGES

ConservationSafety ==
    migrated + queueSize = enqueued

ShutdownBoundarySafety ==
    state = "stopped" => queueSize = 0

=============================================================================
