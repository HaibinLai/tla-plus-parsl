--------------------------- MODULE ParslFileTransferMonitoring ---------------------------
EXTENDS Naturals, Integers, Sequences

(***************************************************************************
 * Versioned file stage-out and monitoring persistence.
 *
 * A logical task can finish while its output is still being transferred.
 * The monitoring event records the file version that was captured by
 * stage-out.  The current branch permits a stale transfer and success event
 * to reach the database; the fixed branch gates both DataFuture readiness and
 * terminal monitoring on a version-matching atomic publication.
 ***************************************************************************)

CONSTANTS CHUNKS, MAX_VERSION, USE_FIXED

ChunkStates == {"none", "sent", "received"}
TransferStates == {"idle", "sending", "ready"}
TaskStates == {"pending", "succeeded"}
MonitorStates == {"none", "queued", "persisted"}
NoFileVersion == -1

VARIABLES sourceVersion, capturedVersion, transfer, chunkState,
          taskState, dataReady, eventState, eventFileVersion,
          dbState, dbFileVersion
vars == <<sourceVersion, capturedVersion, transfer, chunkState,
           taskState, dataReady, eventState, eventFileVersion,
           dbState, dbFileVersion>>

Init ==
    /\ CHUNKS # {}
    /\ MAX_VERSION >= 1
    /\ USE_FIXED \in BOOLEAN
    /\ sourceVersion = 0
    /\ capturedVersion = NoFileVersion
    /\ transfer = "idle"
    /\ chunkState = [c \in CHUNKS |-> "none"]
    /\ taskState = "pending"
    /\ dataReady = FALSE
    /\ eventState = "none"
    /\ eventFileVersion = NoFileVersion
    /\ dbState = "none"
    /\ dbFileVersion = NoFileVersion

StartStageOut ==
    /\ transfer = "idle"
    /\ transfer' = "sending"
    /\ capturedVersion' = sourceVersion
    /\ chunkState' = [c \in CHUNKS |-> "none"]
    /\ UNCHANGED <<sourceVersion, taskState, dataReady, eventState,
                    eventFileVersion, dbState, dbFileVersion>>

ModifySource ==
    /\ transfer = "sending"
    /\ sourceVersion < MAX_VERSION
    /\ sourceVersion' = sourceVersion + 1
    /\ UNCHANGED <<capturedVersion, transfer, chunkState, taskState,
                    dataReady, eventState, eventFileVersion,
                    dbState, dbFileVersion>>

SendChunk(c) ==
    /\ transfer = "sending"
    /\ c \in CHUNKS
    /\ chunkState[c] = "none"
    /\ chunkState' = [chunkState EXCEPT ![c] = "sent"]
    /\ UNCHANGED <<sourceVersion, capturedVersion, transfer, taskState,
                    dataReady, eventState, eventFileVersion,
                    dbState, dbFileVersion>>

ReceiveChunk(c) ==
    /\ transfer = "sending"
    /\ c \in CHUNKS
    /\ chunkState[c] = "sent"
    /\ chunkState' = [chunkState EXCEPT ![c] = "received"]
    /\ UNCHANGED <<sourceVersion, capturedVersion, transfer, taskState,
                    dataReady, eventState, eventFileVersion,
                    dbState, dbFileVersion>>

AllReceived == \A c \in CHUNKS : chunkState[c] = "received"

FinishTask ==
    /\ taskState = "pending"
    /\ taskState' = "succeeded"
    /\ UNCHANGED <<sourceVersion, capturedVersion, transfer, chunkState,
                    dataReady, eventState, eventFileVersion,
                    dbState, dbFileVersion>>

PublishStageOut ==
    /\ transfer = "sending"
    /\ AllReceived
    /\ IF USE_FIXED THEN capturedVersion = sourceVersion ELSE TRUE
    /\ transfer' = "ready"
    /\ dataReady' = TRUE
    /\ UNCHANGED <<sourceVersion, capturedVersion, chunkState, taskState,
                    eventState, eventFileVersion, dbState, dbFileVersion>>

EmitSuccess ==
    /\ taskState = "succeeded"
    /\ eventState = "none"
    /\ IF USE_FIXED THEN dataReady /\ capturedVersion = sourceVersion ELSE TRUE
    /\ eventState' = "queued"
    /\ eventFileVersion' = capturedVersion
    /\ UNCHANGED <<sourceVersion, capturedVersion, transfer, chunkState,
                    taskState, dataReady, dbState, dbFileVersion>>

PersistSuccess ==
    /\ eventState = "queued"
    /\ eventState' = "persisted"
    /\ dbState' = "persisted"
    /\ dbFileVersion' = eventFileVersion
    /\ UNCHANGED <<sourceVersion, capturedVersion, transfer, chunkState,
                    taskState, dataReady, eventFileVersion>>

Next ==
    \/ StartStageOut
    \/ ModifySource
    \/ \E c \in CHUNKS : SendChunk(c) \/ ReceiveChunk(c)
    \/ FinishTask
    \/ PublishStageOut
    \/ EmitSuccess
    \/ PersistSuccess
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ sourceVersion \in 0..MAX_VERSION
    /\ capturedVersion \in -1..MAX_VERSION
    /\ transfer \in TransferStates
    /\ chunkState \in [CHUNKS -> ChunkStates]
    /\ taskState \in TaskStates
    /\ dataReady \in BOOLEAN
    /\ eventState \in MonitorStates
    /\ eventFileVersion \in -1..MAX_VERSION
    /\ dbState \in MonitorStates
    /\ dbFileVersion \in -1..MAX_VERSION

DataFutureSafety ==
    dataReady => /\ transfer = "ready" /\ capturedVersion = sourceVersion

MonitoringFileSafety ==
    dbState = "persisted" =>
        /\ taskState = "succeeded"
        /\ dataReady
        /\ dbFileVersion = sourceVersion

TerminalStability ==
    dbState = "persisted" => taskState = "succeeded"

=============================================================================
