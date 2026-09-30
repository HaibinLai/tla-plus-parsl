--------------------------- MODULE ParslDataFutureTransfer ---------------------------
EXTENDS Naturals, Sequences, FiniteSets

(***************************************************************************
 * A bounded producer -> stage-out -> DataFuture -> consumer protocol.
 *
 * The data manager exposes a DataFuture for an output file.  The consumer
 * must remain blocked until stage-out has published every file chunk.  The
 * current branch intentionally permits publication after only one chunk;
 * the fixed branch requires an atomic all-chunk publication.
 ***************************************************************************)

CONSTANTS CHUNKS, USE_FIXED

ProducerStates == {"new", "running", "done", "failed"}
StageStates == {"idle", "sending", "ready", "failed"}
ChunkStates == {"none", "sent", "received", "corrupt"}
ConsumerStates == {"blocked", "running", "done", "failed"}
FutureStates == {"unresolved", "ready", "failed"}

Source(c) == "source:" \o c
Checksum(token) == token \o ":checksum"
Empty == "none"

VARIABLES producerState, stageState, chunkState, wireToken, wireChecksum,
          bufferToken, dataFuture, consumerState, observed

vars == <<producerState, stageState, chunkState, wireToken, wireChecksum,
          bufferToken, dataFuture, consumerState, observed>>

Init ==
    /\ CHUNKS # {}
    /\ CHUNKS \subseteq STRING
    /\ USE_FIXED \in BOOLEAN
    /\ producerState = "new"
    /\ stageState = "idle"
    /\ chunkState = [c \in CHUNKS |-> "none"]
    /\ wireToken = [c \in CHUNKS |-> Empty]
    /\ wireChecksum = [c \in CHUNKS |-> Empty]
    /\ bufferToken = [c \in CHUNKS |-> Empty]
    /\ dataFuture = "unresolved"
    /\ consumerState = "blocked"
    /\ observed = [c \in CHUNKS |-> Empty]

StartProducer ==
    /\ producerState = "new"
    /\ producerState' = "running"
    /\ UNCHANGED <<stageState, chunkState, wireToken, wireChecksum,
                    bufferToken, dataFuture, consumerState, observed>>

FinishProducer ==
    /\ producerState = "running"
    /\ producerState' = "done"
    /\ UNCHANGED <<stageState, chunkState, wireToken, wireChecksum,
                    bufferToken, dataFuture, consumerState, observed>>

FailProducer ==
    /\ producerState \in {"running", "done"}
    /\ producerState' = "failed"
    /\ stageState' = "failed"
    /\ dataFuture' = "failed"
    /\ consumerState' = "failed"
    /\ UNCHANGED <<chunkState, wireToken, wireChecksum, bufferToken, observed>>

StartStageOut ==
    /\ producerState = "done"
    /\ stageState = "idle"
    /\ stageState' = "sending"
    /\ UNCHANGED <<producerState, chunkState, wireToken, wireChecksum,
                    bufferToken, dataFuture, consumerState, observed>>

SendChunk(c) ==
    /\ stageState = "sending"
    /\ c \in CHUNKS
    /\ chunkState[c] = "none"
    /\ chunkState' = [chunkState EXCEPT ![c] = "sent"]
    /\ wireToken' = [wireToken EXCEPT ![c] = Source(c)]
    /\ wireChecksum' = [wireChecksum EXCEPT ![c] = Checksum(Source(c))]
    /\ UNCHANGED <<producerState, stageState, bufferToken, dataFuture,
                    consumerState, observed>>

CorruptChunk(c) ==
    \* Corruption remains in flight until the receiver rejects the checksum.
    /\ stageState = "sending"
    /\ c \in CHUNKS
    /\ chunkState[c] = "sent"
    /\ chunkState' = [chunkState EXCEPT ![c] = "sent"]
    /\ wireToken' = [wireToken EXCEPT ![c] = @ \o ":corrupt"]
    /\ UNCHANGED <<producerState, stageState, wireChecksum, bufferToken,
                    dataFuture, consumerState, observed>>

ReceiveChunk(c) ==
    /\ stageState = "sending"
    /\ c \in CHUNKS
    /\ chunkState[c] = "sent"
    /\ wireChecksum[c] = Checksum(wireToken[c])
    /\ chunkState' = [chunkState EXCEPT ![c] = "received"]
    /\ bufferToken' = [bufferToken EXCEPT ![c] = wireToken[c]]
    /\ UNCHANGED <<producerState, stageState, wireToken, wireChecksum,
                    dataFuture, consumerState, observed>>

RejectCorrupt(c) ==
    /\ stageState = "sending"
    /\ c \in CHUNKS
    /\ chunkState[c] = "sent"
    /\ wireChecksum[c] # Checksum(wireToken[c])
    /\ chunkState' = [chunkState EXCEPT ![c] = "corrupt"]
    /\ UNCHANGED <<producerState, stageState, wireToken, wireChecksum,
                    bufferToken, dataFuture, consumerState, observed>>

RepairChunk(c) ==
    /\ stageState = "sending"
    /\ c \in CHUNKS
    /\ chunkState[c] = "corrupt"
    /\ chunkState' = [chunkState EXCEPT ![c] = "none"]
    /\ wireToken' = [wireToken EXCEPT ![c] = Empty]
    /\ wireChecksum' = [wireChecksum EXCEPT ![c] = Empty]
    /\ UNCHANGED <<producerState, stageState, bufferToken, dataFuture,
                    consumerState, observed>>

AllReceived ==
    \A c \in CHUNKS : chunkState[c] = "received"

SomeReceived ==
    \E c \in CHUNKS : chunkState[c] = "received"

PublishStageOut ==
    /\ stageState = "sending"
    /\ IF USE_FIXED THEN AllReceived ELSE SomeReceived
    /\ stageState' = "ready"
    /\ dataFuture' = "ready"
    /\ UNCHANGED <<producerState, chunkState, wireToken, wireChecksum,
                    bufferToken, consumerState, observed>>

StartConsumer ==
    /\ consumerState = "blocked"
    /\ dataFuture = "ready"
    /\ consumerState' = "running"
    /\ UNCHANGED <<producerState, stageState, chunkState, wireToken,
                    wireChecksum, bufferToken, dataFuture, observed>>

FinishConsumer ==
    /\ consumerState = "running"
    /\ consumerState' = "done"
    /\ observed' = [c \in CHUNKS |-> bufferToken[c]]
    /\ UNCHANGED <<producerState, stageState, chunkState, wireToken,
                    wireChecksum, bufferToken, dataFuture>>

Next ==
    \/ StartProducer
    \/ FinishProducer
    \/ FailProducer
    \/ StartStageOut
    \/ \E c \in CHUNKS : SendChunk(c) \/ CorruptChunk(c) \/ ReceiveChunk(c)
                               \/ RejectCorrupt(c) \/ RepairChunk(c)
    \/ PublishStageOut
    \/ StartConsumer
    \/ FinishConsumer
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ producerState \in ProducerStates
    /\ stageState \in StageStates
    /\ chunkState \in [CHUNKS -> ChunkStates]
    /\ wireToken \in [CHUNKS -> STRING]
    /\ wireChecksum \in [CHUNKS -> STRING]
    /\ bufferToken \in [CHUNKS -> STRING]
    /\ dataFuture \in FutureStates
    /\ consumerState \in ConsumerStates
    /\ observed \in [CHUNKS -> STRING]

DataFutureGate ==
    consumerState = "running" => dataFuture = "ready"

AtomicPublishSafety ==
    dataFuture = "ready" =>
        /\ producerState = "done"
        /\ AllReceived
        /\ \A c \in CHUNKS : bufferToken[c] = Source(c)

ConsumerContentSafety ==
    consumerState = "done" =>
        /\ dataFuture = "ready"
        /\ \A c \in CHUNKS : observed[c] = Source(c)

FailureSafety ==
    dataFuture = "failed" =>
        /\ producerState = "failed"
        /\ consumerState = "failed"
        /\ stageState = "failed"

=============================================================================
