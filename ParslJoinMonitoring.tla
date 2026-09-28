--------------------------- MODULE ParslJoinMonitoring ---------------------------
EXTENDS Naturals, Sequences, FiniteSets

(***************************************************************************
 * join_app plus asynchronous monitoring persistence.
 *
 * The join has memoized, staged-file, and ordinary inner Futures.  Its outer
 * status is emitted as a versioned monitoring event; radio delivery may
 * reorder events and database writes may fail.  A terminal database row is
 * never replaced by an older/non-terminal event.
 ***************************************************************************)

CONSTANT MAX_VERSION, MAX_QUEUE, MAX_FAILURES
INNER == {"memo", "file", "compute"}
OuterStatuses == {"pending", "joining", "succeeded", "failed"}
InnerStates == {"unresolved", "staging", "running", "succeeded", "failed"}
TerminalInner == {"succeeded", "failed"}
TerminalOuter == {"succeeded", "failed"}
Event == [version : 1..MAX_VERSION, status : OuterStatuses]
NoEvent == [version |-> 0, status |-> "pending"]
EmptyRecord == [version |-> 0, status |-> "pending"]

VARIABLES outerStatus, outerVersion, innerState, dataReady,
          radioQueue, publishedVersion, inFlight, writeState,
          dbRecord, dbFailures
vars == <<outerStatus, outerVersion, innerState, dataReady,
          radioQueue, publishedVersion, inFlight, writeState,
          dbRecord, dbFailures>>

AllInnerDone == \A i \in INNER : innerState[i] \in TerminalInner
HasInnerFailure == \E i \in INNER : innerState[i] = "failed"

Init ==
    /\ MAX_VERSION >= 3
    /\ MAX_QUEUE > 0
    /\ MAX_FAILURES >= 0
    /\ outerStatus = "pending"
    /\ outerVersion = 1
    /\ innerState = [i \in INNER |-> "unresolved"]
    /\ dataReady = [i \in INNER |-> FALSE]
    /\ radioQueue = <<>>
    /\ publishedVersion = 0
    /\ inFlight = NoEvent
    /\ writeState = "idle"
    /\ dbRecord = EmptyRecord
    /\ dbFailures = 0

StartJoin ==
    /\ outerStatus = "pending"
    /\ outerVersion' = outerVersion + 1
    /\ outerStatus' = "joining"
    /\ UNCHANGED <<innerState, dataReady, radioQueue, publishedVersion,
                    inFlight, writeState, dbRecord, dbFailures>>

MemoizeInner ==
    /\ innerState["memo"] = "unresolved"
    /\ innerState' = [innerState EXCEPT !["memo"] = "succeeded"]
    /\ UNCHANGED <<outerStatus, outerVersion, dataReady, radioQueue,
                    publishedVersion, inFlight, writeState, dbRecord, dbFailures>>

BeginStage ==
    /\ innerState["file"] = "unresolved"
    /\ innerState' = [innerState EXCEPT !["file"] = "staging"]
    /\ UNCHANGED <<outerStatus, outerVersion, dataReady, radioQueue,
                    publishedVersion, inFlight, writeState, dbRecord, dbFailures>>

FinishStage ==
    /\ innerState["file"] = "staging"
    /\ innerState' = [innerState EXCEPT !["file"] = "succeeded"]
    /\ dataReady' = [dataReady EXCEPT !["file"] = TRUE]
    /\ UNCHANGED <<outerStatus, outerVersion,
                    radioQueue, publishedVersion, inFlight, writeState,
                    dbRecord, dbFailures>>

StartCompute ==
    /\ innerState["compute"] = "unresolved"
    /\ innerState' = [innerState EXCEPT !["compute"] = "running"]
    /\ UNCHANGED <<outerStatus, outerVersion, dataReady, radioQueue,
                    publishedVersion, inFlight, writeState, dbRecord, dbFailures>>

CompleteCompute ==
    /\ innerState["compute"] = "running"
    /\ innerState' = [innerState EXCEPT !["compute"] = "succeeded"]
    /\ UNCHANGED <<outerStatus, outerVersion, dataReady, radioQueue,
                    publishedVersion, inFlight, writeState, dbRecord, dbFailures>>

FailInner(i) ==
    /\ i \in INNER
    /\ innerState[i] \in {"staging", "running"}
    /\ innerState' = [innerState EXCEPT ![i] = "failed"]
    /\ UNCHANGED <<outerStatus, outerVersion, dataReady, radioQueue,
                    publishedVersion, inFlight, writeState, dbRecord, dbFailures>>

FinalizeJoin ==
    /\ outerStatus = "joining"
    /\ AllInnerDone
    /\ outerVersion < MAX_VERSION
    /\ outerStatus' = IF HasInnerFailure THEN "failed" ELSE "succeeded"
    /\ outerVersion' = outerVersion + 1
    /\ UNCHANGED <<innerState, dataReady, radioQueue, publishedVersion,
                    inFlight, writeState, dbRecord, dbFailures>>

EmitEvent ==
    /\ outerVersion > publishedVersion
    /\ Len(radioQueue) < MAX_QUEUE
    /\ radioQueue' = Append(radioQueue,
          [version |-> outerVersion, status |-> outerStatus])
    /\ publishedVersion' = outerVersion
    /\ UNCHANGED <<outerStatus, outerVersion, innerState, dataReady,
                    inFlight, writeState, dbRecord, dbFailures>>

DeliverHead ==
    /\ writeState = "idle"
    /\ Len(radioQueue) > 0
    /\ inFlight' = Head(radioQueue)
    /\ radioQueue' = Tail(radioQueue)
    /\ writeState' = "writing"
    /\ UNCHANGED <<outerStatus, outerVersion, innerState, dataReady,
                    publishedVersion, dbRecord, dbFailures>>

ReorderRadio ==
    /\ Len(radioQueue) >= 2
    /\ radioQueue' = <<radioQueue[2], radioQueue[1]>>
                    \o SubSeq(radioQueue, 3, Len(radioQueue))
    /\ UNCHANGED <<outerStatus, outerVersion, innerState, dataReady,
                    publishedVersion, inFlight, writeState, dbRecord, dbFailures>>

WriteSuccess ==
    /\ writeState = "writing"
    /\ inFlight # NoEvent
    /\ dbRecord' =
          IF dbRecord.status \notin TerminalOuter
             /\ inFlight.version > dbRecord.version
          THEN inFlight ELSE dbRecord
    /\ inFlight' = NoEvent
    /\ writeState' = "idle"
    /\ UNCHANGED <<outerStatus, outerVersion, innerState, dataReady,
                    radioQueue, publishedVersion, dbFailures>>

WriteFailure ==
    /\ writeState = "writing"
    /\ inFlight # NoEvent
    /\ Len(radioQueue) < MAX_QUEUE
    /\ dbFailures < MAX_FAILURES
    /\ radioQueue' = Append(radioQueue, inFlight)
    /\ inFlight' = NoEvent
    /\ writeState' = "failed"
    /\ dbFailures' = dbFailures + 1
    /\ UNCHANGED <<outerStatus, outerVersion, innerState, dataReady,
                    publishedVersion, dbRecord>>

RetryDatabaseWrite ==
    /\ writeState = "failed"
    /\ writeState' = "idle"
    /\ UNCHANGED <<outerStatus, outerVersion, innerState, dataReady,
                    radioQueue, publishedVersion, inFlight, dbRecord, dbFailures>>

Next ==
    \/ StartJoin
    \/ MemoizeInner
    \/ BeginStage \/ FinishStage
    \/ StartCompute \/ CompleteCompute
    \/ \E i \in INNER : FailInner(i)
    \/ FinalizeJoin
    \/ EmitEvent \/ DeliverHead \/ ReorderRadio
    \/ WriteSuccess \/ WriteFailure \/ RetryDatabaseWrite
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ outerStatus \in OuterStatuses
    /\ outerVersion \in 1..MAX_VERSION
    /\ innerState \in [INNER -> InnerStates]
    /\ dataReady \in [INNER -> BOOLEAN]
    /\ radioQueue \in Seq(Event)
    /\ Len(radioQueue) <= MAX_QUEUE
    /\ publishedVersion \in 0..MAX_VERSION
    /\ inFlight \in {NoEvent} \cup Event
    /\ writeState \in {"idle", "writing", "failed"}
    /\ dbRecord \in {EmptyRecord} \cup
          {[version |-> v, status |-> s] :
              v \in 1..MAX_VERSION, s \in OuterStatuses}
    /\ dbFailures \in 0..MAX_FAILURES

JoinSafety ==
    outerStatus \in TerminalOuter => AllInnerDone

DataSafety ==
    innerState["file"] = "succeeded" => dataReady["file"]

MemoSafety ==
    innerState["memo"] = "succeeded" => TRUE

MonitoringVersionSafety ==
    /\ publishedVersion <= outerVersion
    /\ dbRecord.version <= publishedVersion
    /\ inFlight # NoEvent => inFlight.version <= publishedVersion

MonitoringTerminalSafety ==
    /\ (dbRecord.status = "succeeded" => outerStatus = "succeeded")
    /\ (dbRecord.status = "failed" => outerStatus = "failed")

=============================================================================
