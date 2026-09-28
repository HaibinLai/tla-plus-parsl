--------------------------- MODULE ParslMonitoringDelivery ---------------------------
EXTENDS Naturals, Sequences

(***************************************************************************
 * A compact logical-task -> monitoring-queue -> database model.
 *
 * Events carry a monotonically increasing task version.  The current branch
 * writes an old event after a newer event has already been persisted.  The
 * fixed branch treats that event as stale and preserves the database
 * high-water mark.
 ***************************************************************************)

CONSTANTS MAX_VERSION, MAX_QUEUE, USE_FIXED

Statuses == {"pending", "running", "succeeded", "failed"}
TerminalStatuses == {"succeeded", "failed"}
Event == [version : 1..MAX_VERSION, status : Statuses]
NoEvent == [version |-> 0, status |-> "none"]

VARIABLES logicalStatus, logicalVersion, emittedVersion,
          queue, inFlight, writeState, dbVersion, dbStatus, highWatermark

vars == <<logicalStatus, logicalVersion, emittedVersion,
           queue, inFlight, writeState, dbVersion, dbStatus, highWatermark>>

Init ==
    /\ MAX_VERSION >= 2
    /\ MAX_QUEUE >= 2
    /\ logicalStatus = "pending"
    /\ logicalVersion = 0
    /\ emittedVersion = 0
    /\ queue = <<>>
    /\ inFlight = NoEvent
    /\ writeState = "idle"
    /\ dbVersion = 0
    /\ dbStatus = "none"
    /\ highWatermark = 0

AdvanceStatus(s) ==
    /\ logicalStatus \notin TerminalStatuses
    /\ s \in Statuses
    /\ logicalVersion < MAX_VERSION
    /\ logicalStatus' = s
    /\ logicalVersion' = logicalVersion + 1
    /\ UNCHANGED <<emittedVersion, queue, inFlight, writeState,
                    dbVersion, dbStatus, highWatermark>>

EmitEvent ==
    /\ logicalVersion > emittedVersion
    /\ Len(queue) < MAX_QUEUE
    /\ queue' = Append(queue, [version |-> logicalVersion, status |-> logicalStatus])
    /\ emittedVersion' = logicalVersion
    /\ UNCHANGED <<logicalStatus, logicalVersion, inFlight, writeState,
                    dbVersion, dbStatus, highWatermark>>

DeliverHead ==
    /\ writeState = "idle"
    /\ Len(queue) > 0
    /\ inFlight' = Head(queue)
    /\ queue' = Tail(queue)
    /\ writeState' = "writing"
    /\ UNCHANGED <<logicalStatus, logicalVersion, emittedVersion,
                    dbVersion, dbStatus, highWatermark>>

ReorderQueue ==
    /\ Len(queue) >= 2
    /\ queue' = <<queue[2], queue[1]>>
                    \o SubSeq(queue, 3, Len(queue))
    /\ UNCHANGED <<logicalStatus, logicalVersion, emittedVersion,
                    inFlight, writeState, dbVersion, dbStatus, highWatermark>>

WriteSuccess ==
    /\ writeState = "writing"
    /\ inFlight # NoEvent
    /\ writeState' = "idle"
    /\ inFlight' = NoEvent
    /\ IF USE_FIXED /\ inFlight.version < dbVersion
       THEN /\ dbVersion' = dbVersion
            /\ dbStatus' = dbStatus
       ELSE /\ dbVersion' = inFlight.version
            /\ dbStatus' = inFlight.status
    /\ highWatermark' = IF inFlight.version > highWatermark
                        THEN inFlight.version ELSE highWatermark
    /\ UNCHANGED <<logicalStatus, logicalVersion, emittedVersion, queue>>

Next ==
    \/ \E s \in Statuses : AdvanceStatus(s)
    \/ EmitEvent
    \/ DeliverHead
    \/ ReorderQueue
    \/ WriteSuccess
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ logicalStatus \in Statuses
    /\ logicalVersion \in 0..MAX_VERSION
    /\ emittedVersion \in 0..MAX_VERSION
    /\ queue \in Seq(Event)
    /\ Len(queue) <= MAX_QUEUE
    /\ inFlight \in {NoEvent} \cup Event
    /\ writeState \in {"idle", "writing"}
    /\ dbVersion \in 0..MAX_VERSION
    /\ dbStatus \in Statuses \cup {"none"}
    /\ highWatermark \in 0..MAX_VERSION

DatabaseMonotonic ==
    dbVersion = highWatermark

DatabaseVersionBound ==
    dbVersion <= emittedVersion

TerminalStatusConsistency ==
    dbStatus \in TerminalStatuses => logicalStatus = dbStatus

=============================================================================
