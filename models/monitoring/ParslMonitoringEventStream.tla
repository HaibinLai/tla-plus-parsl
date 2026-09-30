--------------------------- MODULE ParslMonitoringEventStream ---------------------------
EXTENDS Naturals, Sequences, FiniteSets

(***************************************************************************
 * A bounded monitoring producer -> queue -> database-writer stream.
 *
 * Events for several tasks may be reordered, duplicated, retried, or
 * delivered while shutdown is pending.  The database keeps a per-task
 * version high-water mark; an older event must never roll that view back.
 ***************************************************************************)

CONSTANTS TASKS, MAX_VERSION, MAX_QUEUE, MAX_RETRIES, USE_FIXED

Statuses == {"pending", "running", "succeeded", "failed"}
TerminalStatuses == {"succeeded", "failed"}
Events == [task : TASKS, version : 1..MAX_VERSION, status : Statuses]
NoEvent == [task |-> CHOOSE t \in TASKS : TRUE, version |-> 0, status |-> "none"]

VARIABLES logicalVersion, logicalStatus, emittedVersion, queue,
          inFlight, writeState, writeRetries, dbVersion, dbStatus,
          highWatermark, producerClosed, dbClosed
vars == <<logicalVersion, logicalStatus, emittedVersion, queue,
           inFlight, writeState, writeRetries, dbVersion, dbStatus,
           highWatermark, producerClosed, dbClosed>>

Init ==
    /\ TASKS # {}
    /\ MAX_VERSION >= 2
    /\ MAX_QUEUE >= 2
    /\ MAX_RETRIES >= 0
    /\ logicalVersion = [t \in TASKS |-> 0]
    /\ logicalStatus = [t \in TASKS |-> "pending"]
    /\ emittedVersion = [t \in TASKS |-> 0]
    /\ queue = <<>>
    /\ inFlight = NoEvent
    /\ writeState = "idle"
    /\ writeRetries = 0
    /\ dbVersion = [t \in TASKS |-> 0]
    /\ dbStatus = [t \in TASKS |-> "none"]
    /\ highWatermark = [t \in TASKS |-> 0]
    /\ producerClosed = FALSE
    /\ dbClosed = FALSE

AdvanceStatus(t, s) ==
    /\ ~producerClosed
    /\ t \in TASKS
    /\ s \in Statuses
    /\ logicalStatus[t] \notin TerminalStatuses
    /\ logicalVersion[t] < MAX_VERSION
    /\ logicalVersion' = [logicalVersion EXCEPT ![t] = @ + 1]
    /\ logicalStatus' = [logicalStatus EXCEPT ![t] = s]
    /\ UNCHANGED <<emittedVersion, queue, inFlight, writeState,
                    writeRetries, dbVersion, dbStatus, highWatermark,
                    producerClosed, dbClosed>>

Emit(t) ==
    /\ ~producerClosed
    /\ t \in TASKS
    /\ logicalVersion[t] > emittedVersion[t]
    /\ Len(queue) < MAX_QUEUE
    /\ queue' = Append(queue, [task |-> t,
                               version |-> logicalVersion[t],
                               status |-> logicalStatus[t]])
    /\ emittedVersion' = [emittedVersion EXCEPT ![t] = logicalVersion[t]]
    /\ UNCHANGED <<logicalVersion, logicalStatus, inFlight, writeState,
                    writeRetries, dbVersion, dbStatus, highWatermark,
                    producerClosed, dbClosed>>

Duplicate(t) ==
    /\ ~producerClosed
    /\ t \in TASKS
    /\ emittedVersion[t] > 0
    /\ Len(queue) < MAX_QUEUE
    /\ queue' = Append(queue, [task |-> t,
                               version |-> emittedVersion[t],
                               status |-> logicalStatus[t]])
    /\ UNCHANGED <<logicalVersion, logicalStatus, emittedVersion,
                    inFlight, writeState, writeRetries, dbVersion,
                    dbStatus, highWatermark, producerClosed, dbClosed>>

Reorder ==
    /\ Len(queue) >= 2
    /\ queue' = <<queue[2], queue[1]>>
                    \o SubSeq(queue, 3, Len(queue))
    /\ UNCHANGED <<logicalVersion, logicalStatus, emittedVersion,
                    inFlight, writeState, writeRetries, dbVersion,
                    dbStatus, highWatermark, producerClosed, dbClosed>>

Deliver ==
    /\ ~dbClosed
    /\ writeState = "idle"
    /\ Len(queue) > 0
    /\ inFlight' = Head(queue)
    /\ queue' = Tail(queue)
    /\ writeState' = "writing"
    /\ writeRetries' = 0
    /\ UNCHANGED <<logicalVersion, logicalStatus, emittedVersion,
                    dbVersion, dbStatus, highWatermark, producerClosed, dbClosed>>

WriteFailure ==
    /\ writeState = "writing"
    /\ writeRetries < MAX_RETRIES
    /\ Len(queue) < MAX_QUEUE
    /\ queue' = <<inFlight>> \o queue
    /\ writeState' = "idle"
    /\ writeRetries' = writeRetries + 1
    /\ UNCHANGED <<logicalVersion, logicalStatus, emittedVersion,
                    inFlight, dbVersion, dbStatus, highWatermark,
                    producerClosed, dbClosed>>

WriteSuccess ==
    /\ writeState = "writing"
    /\ LET t == inFlight.task IN
        /\ writeState' = "idle"
        /\ inFlight' = NoEvent
        /\ IF USE_FIXED /\ inFlight.version < dbVersion[t]
              THEN /\ dbVersion' = dbVersion
                   /\ dbStatus' = dbStatus
              ELSE /\ dbVersion' = [dbVersion EXCEPT ![t] = inFlight.version]
                   /\ dbStatus' = [dbStatus EXCEPT ![t] = inFlight.status]
        /\ highWatermark' = [highWatermark EXCEPT
                               ![t] = IF @ > inFlight.version
                                     THEN @ ELSE inFlight.version]
    /\ UNCHANGED <<logicalVersion, logicalStatus, emittedVersion,
                    queue, writeRetries, producerClosed, dbClosed>>

CloseProducer ==
    /\ ~producerClosed
    /\ producerClosed' = TRUE
    /\ UNCHANGED <<logicalVersion, logicalStatus, emittedVersion, queue,
                    inFlight, writeState, writeRetries, dbVersion,
                    dbStatus, highWatermark, dbClosed>>

CloseDatabase ==
    /\ producerClosed
    /\ ~dbClosed
    /\ Len(queue) = 0
    /\ writeState = "idle"
    /\ dbClosed' = TRUE
    /\ UNCHANGED <<logicalVersion, logicalStatus, emittedVersion, queue,
                    inFlight, writeState, writeRetries, dbVersion,
                    dbStatus, highWatermark, producerClosed>>

Next ==
    \/ \E t \in TASKS, s \in Statuses : AdvanceStatus(t, s)
    \/ \E t \in TASKS : Emit(t) \/ Duplicate(t)
    \/ Reorder
    \/ Deliver
    \/ WriteFailure
    \/ WriteSuccess
    \/ CloseProducer
    \/ CloseDatabase
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ logicalVersion \in [TASKS -> 0..MAX_VERSION]
    /\ logicalStatus \in [TASKS -> Statuses]
    /\ emittedVersion \in [TASKS -> 0..MAX_VERSION]
    /\ queue \in Seq(Events)
    /\ Len(queue) <= MAX_QUEUE
    /\ inFlight \in {NoEvent} \cup Events
    /\ writeState \in {"idle", "writing"}
    /\ writeRetries \in 0..MAX_RETRIES
    /\ dbVersion \in [TASKS -> 0..MAX_VERSION]
    /\ dbStatus \in [TASKS -> Statuses \cup {"none"}]
    /\ highWatermark \in [TASKS -> 0..MAX_VERSION]
    /\ producerClosed \in BOOLEAN
    /\ dbClosed \in BOOLEAN

DatabaseHighWatermark ==
    \A t \in TASKS : dbVersion[t] = highWatermark[t]

DatabaseVersionBound ==
    \A t \in TASKS : dbVersion[t] <= emittedVersion[t]

ShutdownDrainSafety ==
    dbClosed => producerClosed /\ Len(queue) = 0 /\ writeState = "idle"

TerminalViewSafety ==
    \A t \in TASKS : dbStatus[t] \in TerminalStatuses
        => logicalStatus[t] = dbStatus[t]

=============================================================================
