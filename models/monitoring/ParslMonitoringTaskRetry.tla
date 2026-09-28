--------------------------- MODULE ParslMonitoringTaskRetry ---------------------------
EXTENDS Naturals, Sequences

(***************************************************************************
 * Monitoring records for a retrying logical task.
 *
 * DFK task state is logical, while monitoring events are emitted
 * asynchronously for individual attempts.  The queue can reorder an old
 * attempt's event behind a terminal event.  The current branch lets that
 * old event replace the database view; the fixed branch preserves the
 * database high-water mark and terminal record.
 **************************************************************************)

CONSTANTS MAX_TRIES, MAX_QUEUE, USE_FIXED

Attempts == 0..MAX_TRIES
Statuses == {"pending", "running", "retry_wait", "succeeded", "failed"}
TerminalStatuses == {"succeeded", "failed"}
Event == [version : 1..(2 * MAX_TRIES + 3),
          attempt : Attempts,
          status : Statuses]
NoEvent == [version |-> 0, attempt |-> 0, status |-> "pending"]

VARIABLES logicalStatus, logicalVersion, terminalVersion, currentAttempt,
          emittedVersion, queue, inFlight, writeState,
          dbVersion, dbStatus, highWatermark

vars == <<logicalStatus, logicalVersion, terminalVersion, currentAttempt,
           emittedVersion, queue, inFlight, writeState,
           dbVersion, dbStatus, highWatermark>>

Init ==
    /\ MAX_TRIES >= 1
    /\ MAX_QUEUE >= 2
    /\ USE_FIXED \in BOOLEAN
    /\ logicalStatus = "pending"
    /\ logicalVersion = 0
    /\ terminalVersion = 0
    /\ currentAttempt = 0
    /\ emittedVersion = 0
    /\ queue = <<>>
    /\ inFlight = NoEvent
    /\ writeState = "idle"
    /\ dbVersion = 0
    /\ dbStatus = "pending"
    /\ highWatermark = 0

StartAttempt ==
    /\ logicalStatus \in {"pending", "retry_wait"}
    /\ currentAttempt < MAX_TRIES
    /\ logicalStatus' = "running"
    /\ currentAttempt' = IF logicalStatus = "retry_wait"
                          THEN currentAttempt + 1 ELSE currentAttempt
    /\ logicalVersion' = logicalVersion + 1
    /\ UNCHANGED <<terminalVersion, emittedVersion, queue, inFlight,
                    writeState, dbVersion, dbStatus, highWatermark>>

FailAttempt ==
    /\ logicalStatus = "running"
    /\ logicalStatus' = IF currentAttempt = MAX_TRIES THEN "failed" ELSE "retry_wait"
    /\ logicalVersion' = logicalVersion + 1
    /\ terminalVersion' = IF currentAttempt = MAX_TRIES
                          THEN logicalVersion + 1 ELSE terminalVersion
    /\ UNCHANGED <<currentAttempt, emittedVersion, queue, inFlight,
                    writeState, dbVersion, dbStatus, highWatermark>>

CompleteAttempt ==
    /\ logicalStatus = "running"
    /\ logicalStatus' = "succeeded"
    /\ logicalVersion' = logicalVersion + 1
    /\ terminalVersion' = logicalVersion + 1
    /\ UNCHANGED <<currentAttempt, emittedVersion, queue, inFlight,
                    writeState, dbVersion, dbStatus, highWatermark>>

EmitEvent ==
    /\ logicalVersion > emittedVersion
    /\ Len(queue) < MAX_QUEUE
    /\ queue' = Append(queue,
          [version |-> logicalVersion,
           attempt |-> currentAttempt,
           status |-> logicalStatus])
    /\ emittedVersion' = logicalVersion
    /\ UNCHANGED <<logicalStatus, logicalVersion, terminalVersion,
                    currentAttempt, inFlight, writeState,
                    dbVersion, dbStatus, highWatermark>>

ReorderQueue ==
    /\ Len(queue) >= 2
    /\ queue' = <<queue[2], queue[1]>>
                 \o SubSeq(queue, 3, Len(queue))
    /\ UNCHANGED <<logicalStatus, logicalVersion, terminalVersion,
                    currentAttempt, emittedVersion, inFlight, writeState,
                    dbVersion, dbStatus, highWatermark>>

DeliverHead ==
    /\ writeState = "idle"
    /\ Len(queue) > 0
    /\ inFlight' = Head(queue)
    /\ queue' = Tail(queue)
    /\ writeState' = "writing"
    /\ UNCHANGED <<logicalStatus, logicalVersion, terminalVersion,
                    currentAttempt, emittedVersion,
                    dbVersion, dbStatus, highWatermark>>

WriteSuccess ==
    /\ writeState = "writing"
    /\ LET accept == IF USE_FIXED
                          THEN inFlight.version >= dbVersion
                               /\ dbStatus \notin TerminalStatuses
                          ELSE TRUE
       IN
         /\ dbVersion' = IF accept THEN inFlight.version ELSE dbVersion
         /\ dbStatus' = IF accept THEN inFlight.status ELSE dbStatus
         /\ highWatermark' = IF accept /\ inFlight.version > highWatermark
                             THEN inFlight.version ELSE highWatermark
    /\ inFlight' = NoEvent
    /\ writeState' = "idle"
    /\ UNCHANGED <<logicalStatus, logicalVersion, terminalVersion,
                    currentAttempt, emittedVersion, queue>>

Next ==
    \/ StartAttempt
    \/ FailAttempt
    \/ CompleteAttempt
    \/ EmitEvent
    \/ ReorderQueue
    \/ DeliverHead
    \/ WriteSuccess
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ logicalStatus \in Statuses
    /\ logicalVersion \in 0..(2 * MAX_TRIES + 3)
    /\ terminalVersion \in 0..(2 * MAX_TRIES + 3)
    /\ currentAttempt \in Attempts
    /\ emittedVersion \in 0..(2 * MAX_TRIES + 3)
    /\ queue \in Seq(Event)
    /\ Len(queue) <= MAX_QUEUE
    /\ inFlight \in {NoEvent} \cup Event
    /\ writeState \in {"idle", "writing"}
    /\ dbVersion \in 0..(2 * MAX_TRIES + 3)
    /\ dbStatus \in Statuses
    /\ highWatermark \in 0..(2 * MAX_TRIES + 3)

LogicalTerminalStability ==
    logicalStatus \in TerminalStatuses => terminalVersion > 0

AttemptBound ==
    currentAttempt <= MAX_TRIES

DatabaseVersionSafety ==
    dbVersion = highWatermark

TerminalDatabaseSafety ==
    /\ dbStatus \in TerminalStatuses
       /\ dbVersion >= terminalVersion
       => dbStatus = logicalStatus

=============================================================================
