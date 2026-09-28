--------------------------- MODULE ParslWorkerContactTimeout ---------------------------
EXTENDS Naturals

(***************************************************************************
 * HTEX process-worker-pool heartbeat/contact loop.
 *
 * The worker emits a heartbeat periodically, resets its interchange-contact
 * clock whenever a message arrives, and stops itself when a poll observes no
 * message at or beyond heartbeat_threshold.  A contact at the exact boundary
 * wins because the source handles POLLIN before its no-message timeout check.
 ***************************************************************************)

CONSTANT MAX_TIME
HEARTBEAT_PERIOD == 2
HEARTBEAT_THRESHOLD == 3

WorkerStates == {"running", "stopped"}

VARIABLES now, lastBeat, lastContact, workerState, heartbeatCount
vars == <<now, lastBeat, lastContact, workerState, heartbeatCount>>

Init ==
    /\ MAX_TIME >= HEARTBEAT_THRESHOLD
    /\ now = 0
    /\ lastBeat = 0
    /\ lastContact = 0
    /\ workerState = "running"
    /\ heartbeatCount = 0

Tick ==
    /\ workerState = "running"
    /\ now < MAX_TIME
    /\ now' = now + 1
    /\ UNCHANGED <<lastBeat, lastContact, workerState, heartbeatCount>>

EmitHeartbeat ==
    /\ workerState = "running"
    /\ now >= lastBeat + HEARTBEAT_PERIOD
    /\ lastBeat' = now
    /\ heartbeatCount' = heartbeatCount + 1
    /\ UNCHANGED <<now, lastContact, workerState>>

ReceiveContact ==
    /\ workerState = "running"
    /\ lastContact' = now
    /\ UNCHANGED <<now, lastBeat, workerState, heartbeatCount>>

PollNoMessageBeforeDeadline ==
    /\ workerState = "running"
    /\ now < lastContact + HEARTBEAT_THRESHOLD
    /\ UNCHANGED vars

PollNoMessageAtDeadline ==
    /\ workerState = "running"
    /\ now >= lastContact + HEARTBEAT_THRESHOLD
    /\ workerState' = "stopped"
    /\ UNCHANGED <<now, lastBeat, lastContact, heartbeatCount>>

Next ==
    \/ Tick
    \/ EmitHeartbeat
    \/ ReceiveContact
    \/ PollNoMessageBeforeDeadline
    \/ PollNoMessageAtDeadline
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ now \in 0..MAX_TIME
    /\ lastBeat \in 0..MAX_TIME
    /\ lastContact \in 0..MAX_TIME
    /\ workerState \in WorkerStates
    /\ heartbeatCount \in Nat

ContactExpirySafety ==
    workerState = "stopped" => now - lastContact >= HEARTBEAT_THRESHOLD

HeartbeatScheduleSafety ==
    heartbeatCount > 0 => lastBeat >= HEARTBEAT_PERIOD

=============================================================================
