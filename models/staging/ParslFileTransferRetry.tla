--------------------------- MODULE ParslFileTransferRetry ---------------------------
EXTENDS Naturals, Integers, Sequences

(***************************************************************************
 * File-content versioning across an asynchronous stage-out retry.
 *
 * The producer publishes bytes for a captured source version.  The source
 * file may change while the transfer is in flight.  The current branch
 * publishes the completed old transfer anyway; the fixed branch rejects it
 * as stale and retries from the new source version.  The consumer is released
 * only after an atomic, version-matching publication.
 ***************************************************************************)

CONSTANTS CHUNKS, MAX_VERSION, USE_FIXED

ChunkStates == {"none", "sent", "received", "corrupt"}
TransferStates == {"idle", "sending", "ready", "stale"}
FutureStates == {"unresolved", "ready"}
ConsumerStates == {"blocked", "running", "done"}

Token(c, v) == c \o (IF v = 0 THEN ":v0" ELSE ":v1")
Checksum(x) == x \o ":checksum"
NoValue == "none"

VARIABLES sourceVersion, capturedVersion, sourceToken, transfer,
          chunkState, wireToken, wireChecksum, bufferToken,
          publishedVersion, dataFuture, consumer, observed
vars == <<sourceVersion, capturedVersion, sourceToken, transfer,
           chunkState, wireToken, wireChecksum, bufferToken,
           publishedVersion, dataFuture, consumer, observed>>

Init ==
    /\ CHUNKS # {}
    /\ MAX_VERSION >= 1
    /\ USE_FIXED \in BOOLEAN
    /\ sourceVersion = 0
    /\ capturedVersion = -1
    /\ sourceToken = [c \in CHUNKS |-> Token(c, 0)]
    /\ transfer = "idle"
    /\ chunkState = [c \in CHUNKS |-> "none"]
    /\ wireToken = [c \in CHUNKS |-> NoValue]
    /\ wireChecksum = [c \in CHUNKS |-> NoValue]
    /\ bufferToken = [c \in CHUNKS |-> NoValue]
    /\ publishedVersion = -1
    /\ dataFuture = "unresolved"
    /\ consumer = "blocked"
    /\ observed = [c \in CHUNKS |-> NoValue]

BeginStageOut ==
    /\ transfer = "idle"
    /\ transfer' = "sending"
    /\ capturedVersion' = sourceVersion
    /\ chunkState' = [c \in CHUNKS |-> "none"]
    /\ wireToken' = [c \in CHUNKS |-> NoValue]
    /\ wireChecksum' = [c \in CHUNKS |-> NoValue]
    /\ bufferToken' = [c \in CHUNKS |-> NoValue]
    /\ UNCHANGED <<sourceVersion, sourceToken, publishedVersion,
                    dataFuture, consumer, observed>>

ModifySource ==
    /\ transfer = "sending"
    /\ sourceVersion < MAX_VERSION
    /\ sourceVersion' = sourceVersion + 1
    /\ sourceToken' = [c \in CHUNKS |-> Token(c, sourceVersion + 1)]
    /\ UNCHANGED <<capturedVersion, transfer, chunkState, wireToken,
                    wireChecksum, bufferToken, publishedVersion,
                    dataFuture, consumer, observed>>

SendChunk(c) ==
    /\ transfer = "sending"
    /\ c \in CHUNKS
    /\ chunkState[c] = "none"
    /\ chunkState' = [chunkState EXCEPT ![c] = "sent"]
    /\ wireToken' = [wireToken EXCEPT ![c] = Token(c, capturedVersion)]
    /\ wireChecksum' = [wireChecksum EXCEPT ![c] = Checksum(Token(c, capturedVersion))]
    /\ UNCHANGED <<sourceVersion, capturedVersion, sourceToken, transfer,
                    bufferToken, publishedVersion, dataFuture,
                    consumer, observed>>

ReceiveChunk(c) ==
    /\ transfer = "sending"
    /\ c \in CHUNKS
    /\ chunkState[c] = "sent"
    /\ wireChecksum[c] = Checksum(wireToken[c])
    /\ chunkState' = [chunkState EXCEPT ![c] = "received"]
    /\ bufferToken' = [bufferToken EXCEPT ![c] = wireToken[c]]
    /\ UNCHANGED <<sourceVersion, capturedVersion, sourceToken, transfer,
                    wireToken, wireChecksum, publishedVersion,
                    dataFuture, consumer, observed>>

CorruptChunk(c) ==
    /\ transfer = "sending"
    /\ c \in CHUNKS
    /\ chunkState[c] = "sent"
    /\ wireChecksum' = [wireChecksum EXCEPT ![c] = @ \o ":bad"]
    /\ chunkState' = [chunkState EXCEPT ![c] = "sent"]
    /\ UNCHANGED <<sourceVersion, capturedVersion, sourceToken, transfer,
                    wireToken, bufferToken, publishedVersion, dataFuture,
                    consumer, observed>>

RejectCorruptChunk(c) ==
    /\ transfer = "sending"
    /\ c \in CHUNKS
    /\ chunkState[c] = "sent"
    /\ wireChecksum[c] # Checksum(wireToken[c])
    /\ chunkState' = [chunkState EXCEPT ![c] = "corrupt"]
    /\ UNCHANGED <<sourceVersion, capturedVersion, sourceToken, transfer,
                    wireToken, wireChecksum, bufferToken, publishedVersion,
                    dataFuture, consumer, observed>>

RepairChunk(c) ==
    /\ transfer = "sending"
    /\ c \in CHUNKS
    /\ chunkState[c] = "corrupt"
    /\ chunkState' = [chunkState EXCEPT ![c] = "none"]
    /\ UNCHANGED <<sourceVersion, capturedVersion, sourceToken, transfer,
                    wireToken, wireChecksum, bufferToken, publishedVersion,
                    dataFuture, consumer, observed>>

AllReceived == \A c \in CHUNKS : chunkState[c] = "received"

Publish ==
    /\ transfer = "sending"
    /\ AllReceived
    /\ IF USE_FIXED THEN capturedVersion = sourceVersion ELSE TRUE
    /\ transfer' = IF USE_FIXED /\ capturedVersion # sourceVersion
                     THEN "stale" ELSE "ready"
    /\ publishedVersion' = IF USE_FIXED /\ capturedVersion # sourceVersion
                           THEN publishedVersion ELSE capturedVersion
    /\ dataFuture' = IF USE_FIXED /\ capturedVersion # sourceVersion
                     THEN dataFuture ELSE "ready"
    /\ UNCHANGED <<sourceVersion, capturedVersion, sourceToken, chunkState,
                    wireToken, wireChecksum, bufferToken, consumer, observed>>

RetryStale ==
    /\ transfer = "stale"
    /\ transfer' = "sending"
    /\ capturedVersion' = sourceVersion
    /\ chunkState' = [c \in CHUNKS |-> "none"]
    /\ wireToken' = [c \in CHUNKS |-> NoValue]
    /\ wireChecksum' = [c \in CHUNKS |-> NoValue]
    /\ bufferToken' = [c \in CHUNKS |-> NoValue]
    /\ UNCHANGED <<sourceVersion, sourceToken, publishedVersion,
                    dataFuture, consumer, observed>>

StartConsumer ==
    /\ consumer = "blocked"
    /\ dataFuture = "ready"
    /\ consumer' = "running"
    /\ UNCHANGED <<sourceVersion, capturedVersion, sourceToken, transfer,
                    chunkState, wireToken, wireChecksum, bufferToken,
                    publishedVersion, dataFuture, observed>>

FinishConsumer ==
    /\ consumer = "running"
    /\ consumer' = "done"
    /\ observed' = bufferToken
    /\ UNCHANGED <<sourceVersion, capturedVersion, sourceToken, transfer,
                    chunkState, wireToken, wireChecksum, bufferToken,
                    publishedVersion, dataFuture>>

Next ==
    \/ BeginStageOut
    \/ ModifySource
    \/ \E c \in CHUNKS : SendChunk(c) \/ ReceiveChunk(c) \/ CorruptChunk(c)
                               \/ RejectCorruptChunk(c) \/ RepairChunk(c)
    \/ Publish
    \/ RetryStale
    \/ StartConsumer
    \/ FinishConsumer
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ sourceVersion \in 0..MAX_VERSION
    /\ capturedVersion \in -1..MAX_VERSION
    /\ sourceToken \in [CHUNKS -> STRING]
    /\ transfer \in TransferStates
    /\ chunkState \in [CHUNKS -> ChunkStates]
    /\ wireToken \in [CHUNKS -> STRING]
    /\ wireChecksum \in [CHUNKS -> STRING]
    /\ bufferToken \in [CHUNKS -> STRING]
    /\ publishedVersion \in -1..MAX_VERSION
    /\ dataFuture \in FutureStates
    /\ consumer \in ConsumerStates
    /\ observed \in [CHUNKS -> STRING]

PublicationSafety ==
    dataFuture = "ready" =>
        /\ transfer = "ready"
        /\ publishedVersion = sourceVersion
        /\ AllReceived

ConsumerSafety ==
    consumer = "running" => dataFuture = "ready"

ContentSafety ==
    consumer = "done" =>
        /\ publishedVersion = sourceVersion
        /\ \A c \in CHUNKS : observed[c] = Token(c, sourceVersion)

StaleSafety ==
    transfer = "stale" => capturedVersion # sourceVersion

CorruptionRejectionSafety ==
    \A c \in CHUNKS :
        chunkState[c] = "corrupt"
            => wireChecksum[c] # Checksum(wireToken[c])

=============================================================================
