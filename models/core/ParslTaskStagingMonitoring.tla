--------------------------- MODULE ParslTaskStagingMonitoring ---------------------------
EXTENDS Naturals, Sequences, FiniteSets

(***************************************************************************
 * A small cross-component model for a producer task, output stage-out,
 * a dependent consumer, and asynchronous monitoring persistence.
 *
 * The current branch intentionally permits the producer success event and
 * DataFuture readiness after only one output chunk.  The fixed branch makes
 * both observations depend on complete stage-out.  This is the boundary
 * between DataFlowKernel task state, DataManager/DataFuture readiness, and
 * monitoring state rather than a model of any one implementation class.
 ***************************************************************************)

CONSTANTS CHUNKS, USE_FIXED

ProducerStates == {"new", "running", "done"}
StageStates == {"idle", "sending", "ready"}
ChunkStates == {"none", "sent", "received"}
FutureStates == {"unresolved", "ready"}
ConsumerStates == {"blocked", "running", "done"}
MonitorStates == {"none", "queued", "persisted"}

VARIABLES producer, stage, chunks, dataFuture, consumer,
          monitor, monitorDB
vars == <<producer, stage, chunks, dataFuture, consumer, monitor, monitorDB>>

Init ==
    /\ CHUNKS # {}
    /\ CHUNKS \subseteq STRING
    /\ USE_FIXED \in BOOLEAN
    /\ producer = "new"
    /\ stage = "idle"
    /\ chunks = [c \in CHUNKS |-> "none"]
    /\ dataFuture = "unresolved"
    /\ consumer = "blocked"
    /\ monitor = "none"
    /\ monitorDB = "none"

StartProducer ==
    /\ producer = "new"
    /\ producer' = "running"
    /\ UNCHANGED <<stage, chunks, dataFuture, consumer, monitor, monitorDB>>

FinishProducer ==
    /\ producer = "running"
    /\ producer' = "done"
    /\ UNCHANGED <<stage, chunks, dataFuture, consumer, monitor, monitorDB>>

StartStageOut ==
    /\ producer = "done"
    /\ stage = "idle"
    /\ stage' = "sending"
    /\ UNCHANGED <<producer, chunks, dataFuture, consumer, monitor, monitorDB>>

SendChunk(c) ==
    /\ stage = "sending"
    /\ c \in CHUNKS
    /\ chunks[c] = "none"
    /\ chunks' = [chunks EXCEPT ![c] = "sent"]
    /\ UNCHANGED <<producer, stage, dataFuture, consumer, monitor, monitorDB>>

ReceiveChunk(c) ==
    /\ stage = "sending"
    /\ c \in CHUNKS
    /\ chunks[c] = "sent"
    /\ chunks' = [chunks EXCEPT ![c] = "received"]
    /\ UNCHANGED <<producer, stage, dataFuture, consumer, monitor, monitorDB>>

AllReceived == \A c \in CHUNKS : chunks[c] = "received"
SomeReceived == \E c \in CHUNKS : chunks[c] = "received"

PublishStageOut ==
    /\ stage = "sending"
    /\ IF USE_FIXED THEN AllReceived ELSE SomeReceived
    /\ stage' = "ready"
    /\ dataFuture' = "ready"
    /\ UNCHANGED <<producer, chunks, consumer, monitor, monitorDB>>

EmitProducerSuccess ==
    /\ producer = "done"
    /\ monitor = "none"
    /\ IF USE_FIXED THEN dataFuture = "ready" ELSE TRUE
    /\ monitor' = "queued"
    /\ UNCHANGED <<producer, stage, chunks, dataFuture, consumer, monitorDB>>

PersistProducerSuccess ==
    /\ monitor = "queued"
    /\ monitor' = "persisted"
    /\ monitorDB' = "persisted"
    /\ UNCHANGED <<producer, stage, chunks, dataFuture, consumer>>

StartConsumer ==
    /\ consumer = "blocked"
    /\ dataFuture = "ready"
    /\ consumer' = "running"
    /\ UNCHANGED <<producer, stage, chunks, dataFuture, monitor, monitorDB>>

FinishConsumer ==
    /\ consumer = "running"
    /\ consumer' = "done"
    /\ UNCHANGED <<producer, stage, chunks, dataFuture, monitor, monitorDB>>

Next ==
    \/ StartProducer
    \/ FinishProducer
    \/ StartStageOut
    \/ \E c \in CHUNKS : SendChunk(c) \/ ReceiveChunk(c)
    \/ PublishStageOut
    \/ EmitProducerSuccess
    \/ PersistProducerSuccess
    \/ StartConsumer
    \/ FinishConsumer
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ producer \in ProducerStates
    /\ stage \in StageStates
    /\ chunks \in [CHUNKS -> ChunkStates]
    /\ dataFuture \in FutureStates
    /\ consumer \in ConsumerStates
    /\ monitor \in MonitorStates
    /\ monitorDB \in MonitorStates

DependencySafety ==
    consumer = "running" => dataFuture = "ready"

StageReadySafety ==
    dataFuture = "ready" => /\ producer = "done" /\ stage = "ready" /\ AllReceived

MonitoringSafety ==
    monitorDB = "persisted" => /\ producer = "done" /\ dataFuture = "ready"

ConsumerOutputSafety ==
    consumer = "done" => /\ dataFuture = "ready" /\ AllReceived

=============================================================================
