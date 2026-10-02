--------------------------- MODULE ParslFileBytesAttemptGate ---------------------------
EXTENDS Naturals, Integers, Sequences

(***************************************************************************
 * Byte-level stage-in with a logical retry boundary.
 *
 * The transfer carries versioned chunk tokens and checksums.  A logical task
 * retry may happen while the old physical transfer is still in flight.  The
 * unsafe branch publishes that old transfer as the new DataFuture; the fixed
 * branch requires both the logical attempt and source version to match before
 * publication, then restarts the transfer.
 ***************************************************************************)

CONSTANTS CHUNKS, MAX_ATTEMPTS, USE_FIXED

ChunkStates == {"none", "sent", "received", "corrupt"}
TransferStates == {"idle", "sending", "stale", "ready"}
FutureStates == {"unresolved", "ready"}
TaskStates == {"blocked", "running", "done"}
NoValue == <<"none">>

Token(c, a, v) == <<c, a, v>>
Checksum(x) == <<"sha", x>>

VARIABLES attempt, sourceVersion, capturedAttempt, capturedVersion,
          transfer, chunkState, wireToken, wireChecksum, bufferToken,
          dataFuture, task, publishedAttempt, publishedVersion, observed
vars == <<attempt, sourceVersion, capturedAttempt, capturedVersion,
           transfer, chunkState, wireToken, wireChecksum, bufferToken,
           dataFuture, task, publishedAttempt, publishedVersion, observed>>

Init ==
    /\ CHUNKS # {}
    /\ MAX_ATTEMPTS >= 1
    /\ USE_FIXED \in BOOLEAN
    /\ attempt = 0
    /\ sourceVersion = 0
    /\ capturedAttempt = -1
    /\ capturedVersion = -1
    /\ transfer = "idle"
    /\ chunkState = [c \in CHUNKS |-> "none"]
    /\ wireToken = [c \in CHUNKS |-> NoValue]
    /\ wireChecksum = [c \in CHUNKS |-> NoValue]
    /\ bufferToken = [c \in CHUNKS |-> NoValue]
    /\ dataFuture = "unresolved"
    /\ task = "blocked"
    /\ publishedAttempt = -1
    /\ publishedVersion = -1
    /\ observed = [c \in CHUNKS |-> NoValue]

BeginStageIn ==
    /\ transfer = "idle"
    /\ transfer' = "sending"
    /\ capturedAttempt' = attempt
    /\ capturedVersion' = sourceVersion
    /\ chunkState' = [c \in CHUNKS |-> "none"]
    /\ wireToken' = [c \in CHUNKS |-> NoValue]
    /\ wireChecksum' = [c \in CHUNKS |-> NoValue]
    /\ bufferToken' = [c \in CHUNKS |-> NoValue]
    /\ UNCHANGED <<attempt, sourceVersion, dataFuture, task,
                    publishedAttempt, publishedVersion, observed>>

ModifySource ==
    /\ transfer = "sending"
    /\ sourceVersion = 0
    /\ sourceVersion' = 1
    /\ UNCHANGED <<attempt, capturedAttempt, capturedVersion, transfer,
                    chunkState, wireToken, wireChecksum, bufferToken,
                    dataFuture, task, publishedAttempt, publishedVersion,
                    observed>>

RetryLogicalTask ==
    /\ transfer = "sending"
    /\ task = "blocked"
    /\ attempt < MAX_ATTEMPTS
    /\ attempt' = attempt + 1
    /\ dataFuture' = "unresolved"
    /\ UNCHANGED <<sourceVersion, capturedAttempt, capturedVersion,
                    transfer, chunkState, wireToken, wireChecksum,
                    bufferToken, task, publishedAttempt, publishedVersion,
                    observed>>

SendChunk(c) ==
    /\ transfer = "sending"
    /\ c \in CHUNKS
    /\ chunkState[c] = "none"
    /\ chunkState' = [chunkState EXCEPT ![c] = "sent"]
    /\ wireToken' = [wireToken EXCEPT ![c] = Token(c, capturedAttempt, capturedVersion)]
    /\ wireChecksum' = [wireChecksum EXCEPT ![c] = Checksum(Token(c, capturedAttempt, capturedVersion))]
    /\ UNCHANGED <<attempt, sourceVersion, capturedAttempt, capturedVersion,
                    transfer, bufferToken, dataFuture, task,
                    publishedAttempt, publishedVersion, observed>>

ReceiveChunk(c) ==
    /\ transfer = "sending"
    /\ c \in CHUNKS
    /\ chunkState[c] = "sent"
    /\ wireChecksum[c] = Checksum(wireToken[c])
    /\ chunkState' = [chunkState EXCEPT ![c] = "received"]
    /\ bufferToken' = [bufferToken EXCEPT ![c] = wireToken[c]]
    /\ UNCHANGED <<attempt, sourceVersion, capturedAttempt, capturedVersion,
                    transfer, wireToken, wireChecksum, dataFuture, task,
                    publishedAttempt, publishedVersion, observed>>

CorruptChunk(c) ==
    /\ transfer = "sending"
    /\ c \in CHUNKS
    /\ chunkState[c] = "sent"
    /\ wireChecksum[c] = Checksum(wireToken[c])
    /\ wireChecksum' = [wireChecksum EXCEPT ![c] = <<"bad", wireToken[c]>>]
    /\ UNCHANGED <<attempt, sourceVersion, capturedAttempt, capturedVersion,
                    transfer, chunkState, wireToken, bufferToken,
                    dataFuture, task, publishedAttempt, publishedVersion,
                    observed>>

RejectCorrupt(c) ==
    /\ transfer = "sending"
    /\ c \in CHUNKS
    /\ chunkState[c] = "sent"
    /\ wireChecksum[c] # Checksum(wireToken[c])
    /\ chunkState' = [chunkState EXCEPT ![c] = "corrupt"]
    /\ UNCHANGED <<attempt, sourceVersion, capturedAttempt, capturedVersion,
                    transfer, wireToken, wireChecksum, bufferToken,
                    dataFuture, task, publishedAttempt, publishedVersion,
                    observed>>

RepairChunk(c) ==
    /\ transfer = "sending"
    /\ c \in CHUNKS
    /\ chunkState[c] = "corrupt"
    /\ chunkState' = [chunkState EXCEPT ![c] = "none"]
    /\ UNCHANGED <<attempt, sourceVersion, capturedAttempt, capturedVersion,
                    transfer, wireToken, wireChecksum, bufferToken,
                    dataFuture, task, publishedAttempt, publishedVersion,
                    observed>>

AllReceived == \A c \in CHUNKS : chunkState[c] = "received"

Publish ==
    /\ transfer = "sending"
    /\ AllReceived
    /\ IF USE_FIXED /\ (capturedAttempt # attempt \/ capturedVersion # sourceVersion)
          THEN /\ transfer' = "stale"
               /\ UNCHANGED <<dataFuture, publishedAttempt, publishedVersion>>
          ELSE /\ transfer' = "ready"
               /\ dataFuture' = "ready"
               /\ publishedAttempt' = capturedAttempt
               /\ publishedVersion' = capturedVersion
    /\ UNCHANGED <<attempt, sourceVersion, capturedAttempt, capturedVersion,
                    chunkState, wireToken, wireChecksum, bufferToken,
                    task, observed>>

RetryStale ==
    /\ transfer = "stale"
    /\ transfer' = "idle"
    /\ UNCHANGED <<attempt, sourceVersion, capturedAttempt, capturedVersion,
                    chunkState, wireToken, wireChecksum, bufferToken,
                    dataFuture, task, publishedAttempt, publishedVersion,
                    observed>>

StartTask ==
    /\ task = "blocked"
    /\ dataFuture = "ready"
    /\ task' = "running"
    /\ UNCHANGED <<attempt, sourceVersion, capturedAttempt, capturedVersion,
                    transfer, chunkState, wireToken, wireChecksum,
                    bufferToken, dataFuture, publishedAttempt,
                    publishedVersion, observed>>

CompleteTask ==
    /\ task = "running"
    /\ task' = "done"
    /\ observed' = bufferToken
    /\ UNCHANGED <<attempt, sourceVersion, capturedAttempt, capturedVersion,
                    transfer, chunkState, wireToken, wireChecksum,
                    bufferToken, dataFuture, publishedAttempt, publishedVersion>>

Next ==
    \/ BeginStageIn
    \/ ModifySource
    \/ RetryLogicalTask
    \/ \E c \in CHUNKS : SendChunk(c) \/ ReceiveChunk(c) \/ CorruptChunk(c)
                              \/ RejectCorrupt(c) \/ RepairChunk(c)
    \/ Publish
    \/ RetryStale
    \/ StartTask
    \/ CompleteTask
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ attempt \in 0..MAX_ATTEMPTS
    /\ sourceVersion \in 0..1
    /\ capturedAttempt \in -1..MAX_ATTEMPTS
    /\ capturedVersion \in -1..1
    /\ transfer \in TransferStates
    /\ chunkState \in [CHUNKS -> ChunkStates]
    /\ wireToken \in [CHUNKS -> (CHUNKS \X (-1..MAX_ATTEMPTS) \X (-1..1)) \cup {NoValue}]
    /\ bufferToken \in [CHUNKS -> (CHUNKS \X (-1..MAX_ATTEMPTS) \X (-1..1)) \cup {NoValue}]
    /\ dataFuture \in FutureStates
    /\ task \in TaskStates
    /\ publishedAttempt \in -1..MAX_ATTEMPTS
    /\ publishedVersion \in -1..1
    /\ observed \in [CHUNKS -> (CHUNKS \X (0..MAX_ATTEMPTS) \X (0..1)) \cup {NoValue}]

AttemptRetryBound == attempt \in 0..MAX_ATTEMPTS

PublicationSafety ==
    dataFuture = "ready" =>
        /\ transfer = "ready"
        /\ publishedAttempt = attempt
        /\ publishedVersion = sourceVersion
        /\ AllReceived

ChecksumSafety ==
    \A c \in CHUNKS :
        chunkState[c] = "received" =>
            /\ wireChecksum[c] = Checksum(wireToken[c])
            /\ bufferToken[c] = wireToken[c]

DependencySafety == task = "running" => dataFuture = "ready"

ContentSafety ==
    task = "done" =>
        /\ publishedAttempt = attempt
        /\ publishedVersion = sourceVersion
        /\ \A c \in CHUNKS : observed[c] = Token(c, attempt, sourceVersion)

StaleTransferSafety ==
    transfer = "stale" =>
        capturedAttempt # attempt \/ capturedVersion # sourceVersion

=================================================================================
