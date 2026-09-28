--------------------------- MODULE ParslMonitoringDB ---------------------------
EXTENDS Naturals, Integers, Sequences

(***************************************************************************
 * A focused asynchronous monitoring/radio/database model.
 *
 * The logical task emits versioned status events into a radio queue.  Events
 * can be delivered out of order, a database write can fail and be retried,
 * and stale/duplicate writes are ignored.  Terminal database records are
 * immutable even if an old event remains in the queue.
 ***************************************************************************)

CONSTANTS MAX_VERSION, MAX_QUEUE, MAX_FAILURES

Statuses == {"pending", "running", "retry_wait", "succeeded", "failed"}
TerminalStatuses == {"succeeded", "failed"}
RecordStatuses == Statuses \cup {"none"}
WriteStates == {"idle", "writing", "failed"}
Event == [version : 1..MAX_VERSION, status : Statuses]
NoEvent == [version |-> -1, status |-> "none"]
EmptyRecord == [version |-> 0, status |-> "none"]

VARIABLES logicalStatus, logicalVersion, publishedVersion,
          radioQueue, inFlight, writeState, dbRecord, dbFailures

vars == <<logicalStatus, logicalVersion, publishedVersion,
           radioQueue, inFlight, writeState, dbRecord, dbFailures>>

Init ==
    /\ MAX_VERSION >= 2
    /\ MAX_QUEUE > 0
    /\ MAX_FAILURES >= 0
    /\ logicalStatus = "none"
    /\ logicalVersion = 0
    /\ publishedVersion = 0
    /\ radioQueue = <<>>
    /\ inFlight = NoEvent
    /\ writeState = "idle"
    /\ dbRecord = EmptyRecord
    /\ dbFailures = 0

AdvanceStatus(s) ==
    /\ logicalStatus \notin TerminalStatuses
    /\ s \in Statuses
    /\ logicalVersion < MAX_VERSION
    /\ logicalStatus' = s
    /\ logicalVersion' = logicalVersion + 1
    /\ UNCHANGED <<publishedVersion, radioQueue, inFlight, writeState,
                    dbRecord, dbFailures>>

EmitEvent ==
    /\ logicalVersion > publishedVersion
    /\ Len(radioQueue) < MAX_QUEUE
    /\ radioQueue' = Append(radioQueue,
          [version |-> logicalVersion, status |-> logicalStatus])
    /\ publishedVersion' = logicalVersion
    /\ UNCHANGED <<logicalStatus, logicalVersion, inFlight, writeState,
                    dbRecord, dbFailures>>

DeliverHead ==
    /\ writeState = "idle"
    /\ Len(radioQueue) > 0
    /\ inFlight' = Head(radioQueue)
    /\ radioQueue' = Tail(radioQueue)
    /\ writeState' = "writing"
    /\ UNCHANGED <<logicalStatus, logicalVersion, publishedVersion,
                    dbRecord, dbFailures>>

ReorderRadio ==
    /\ Len(radioQueue) >= 2
    /\ radioQueue' = <<radioQueue[2], radioQueue[1]>>
                    \o SubSeq(radioQueue, 3, Len(radioQueue))
    /\ UNCHANGED <<logicalStatus, logicalVersion, publishedVersion,
                    inFlight, writeState, dbRecord, dbFailures>>

WriteSuccess ==
    /\ writeState = "writing"
    /\ inFlight # NoEvent
    /\ dbRecord' =
          IF dbRecord.status \notin TerminalStatuses
             /\ inFlight.version > dbRecord.version
          THEN inFlight ELSE dbRecord
    /\ inFlight' = NoEvent
    /\ writeState' = "idle"
    /\ UNCHANGED <<logicalStatus, logicalVersion, publishedVersion,
                    radioQueue, dbFailures>>

WriteFailure ==
    /\ writeState = "writing"
    /\ inFlight # NoEvent
    /\ Len(radioQueue) < MAX_QUEUE
    /\ dbFailures < MAX_FAILURES
    /\ radioQueue' = Append(radioQueue, inFlight)
    /\ inFlight' = NoEvent
    /\ writeState' = "failed"
    /\ dbFailures' = dbFailures + 1
    /\ UNCHANGED <<logicalStatus, logicalVersion, publishedVersion, dbRecord>>

RetryDatabaseWrite ==
    /\ writeState = "failed"
    /\ writeState' = "idle"
    /\ UNCHANGED <<logicalStatus, logicalVersion, publishedVersion,
                    radioQueue, inFlight, dbRecord, dbFailures>>

Next ==
    \/ \E s \in Statuses : AdvanceStatus(s)
    \/ EmitEvent
    \/ DeliverHead
    \/ ReorderRadio
    \/ WriteSuccess
    \/ WriteFailure
    \/ RetryDatabaseWrite
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ logicalStatus \in RecordStatuses
    /\ logicalVersion \in 0..MAX_VERSION
    /\ publishedVersion \in 0..MAX_VERSION
    /\ radioQueue \in Seq(Event)
    /\ Len(radioQueue) <= MAX_QUEUE
    /\ inFlight \in {NoEvent} \cup Event
    /\ writeState \in WriteStates
    /\ dbRecord \in {EmptyRecord} \cup
          {[version |-> v, status |-> s] :
              v \in 1..MAX_VERSION, s \in Statuses}
    /\ dbFailures \in 0..MAX_FAILURES

VersionSafety ==
    /\ dbRecord.version <= logicalVersion
    /\ dbRecord.version <= publishedVersion
    /\ publishedVersion <= logicalVersion
    /\ inFlight # NoEvent => inFlight.version <= publishedVersion

DatabaseConsistency ==
    /\ dbRecord.status = "none" => dbRecord.version = 0
    /\ dbRecord.version = logicalVersion
        => dbRecord.status = logicalStatus
    /\ dbRecord.status \in TerminalStatuses
        => logicalStatus = dbRecord.status

WriteFailureSafety ==
    writeState = "failed" => inFlight = NoEvent

=============================================================================
