--------------------------- MODULE ParslDataTransferDependencyFailure ---------------------------
EXTENDS Naturals, FiniteSets

(***************************************************************************
 * Cross-layer file stage-out and dependency failure.
 *
 * A producer application creates an output file.  The DataManager stage-out
 * Future publishes a DataFuture only after all chunks have arrived.  If the
 * transfer fails, a consumer receiving that DataFuture must complete as a
 * dependency failure and must not execute with a partial file.
 ***************************************************************************)

CONSTANTS CHUNKS, USE_FIXED

ProducerStates == {"new", "running", "done", "failed"}
StageStates == {"idle", "sending", "ready", "failed"}
ChunkStates == {"none", "sent", "received"}
FutureStates == {"unresolved", "ready", "failed"}
ConsumerStates == {"blocked", "running", "done", "dep_failed"}

VARIABLES producer, stage, chunks, dataFuture, consumer, observed
vars == <<producer, stage, chunks, dataFuture, consumer, observed>>

AllReceived == \A c \in CHUNKS : chunks[c] = "received"

Init ==
    /\ CHUNKS # {}
    /\ USE_FIXED \in BOOLEAN
    /\ producer = "new"
    /\ stage = "idle"
    /\ chunks = [c \in CHUNKS |-> "none"]
    /\ dataFuture = "unresolved"
    /\ consumer = "blocked"
    /\ observed = "none"

StartProducer ==
    /\ producer = "new"
    /\ producer' = "running"
    /\ UNCHANGED <<stage, chunks, dataFuture, consumer, observed>>

FinishProducer ==
    /\ producer = "running"
    /\ producer' = "done"
    /\ UNCHANGED <<stage, chunks, dataFuture, consumer, observed>>

FailProducer ==
    /\ producer = "running"
    /\ producer' = "failed"
    /\ stage' = "failed"
    /\ dataFuture' = "failed"
    /\ consumer' = "dep_failed"
    /\ UNCHANGED <<chunks, observed>>

StartStageOut ==
    /\ producer = "done"
    /\ stage = "idle"
    /\ stage' = "sending"
    /\ UNCHANGED <<producer, chunks, dataFuture, consumer, observed>>

SendChunk(c) ==
    /\ stage = "sending"
    /\ c \in CHUNKS
    /\ chunks[c] = "none"
    /\ chunks' = [chunks EXCEPT ![c] = "sent"]
    /\ UNCHANGED <<producer, stage, dataFuture, consumer, observed>>

ReceiveChunk(c) ==
    /\ stage = "sending"
    /\ c \in CHUNKS
    /\ chunks[c] = "sent"
    /\ chunks' = [chunks EXCEPT ![c] = "received"]
    /\ UNCHANGED <<producer, stage, dataFuture, consumer, observed>>

FailStageOut ==
    /\ stage = "sending"
    /\ stage' = "failed"
    /\ dataFuture' = "failed"
    /\ UNCHANGED <<producer, chunks, consumer, observed>>

PublishStageOut ==
    /\ stage = "sending"
    /\ AllReceived
    /\ stage' = "ready"
    /\ dataFuture' = "ready"
    /\ UNCHANGED <<producer, chunks, consumer, observed>>

StartConsumer ==
    /\ consumer = "blocked"
    /\ IF USE_FIXED
          THEN dataFuture = "ready"
          ELSE dataFuture \in {"ready", "failed"}
    /\ consumer' = "running"
    /\ UNCHANGED <<producer, stage, chunks, dataFuture, observed>>

PropagateFailure ==
    /\ consumer = "blocked"
    /\ dataFuture = "failed"
    /\ consumer' = IF USE_FIXED THEN "dep_failed" ELSE consumer
    /\ UNCHANGED <<producer, stage, chunks, dataFuture, observed>>

CompleteConsumer ==
    /\ consumer = "running"
    /\ consumer' = "done"
    /\ observed' = "complete-file"
    /\ UNCHANGED <<producer, stage, chunks, dataFuture>>

Next ==
    \/ StartProducer
    \/ FinishProducer
    \/ FailProducer
    \/ StartStageOut
    \/ \E c \in CHUNKS : SendChunk(c) \/ ReceiveChunk(c)
    \/ FailStageOut
    \/ PublishStageOut
    \/ StartConsumer
    \/ PropagateFailure
    \/ CompleteConsumer
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ producer \in ProducerStates
    /\ stage \in StageStates
    /\ chunks \in [CHUNKS -> ChunkStates]
    /\ dataFuture \in FutureStates
    /\ consumer \in ConsumerStates
    /\ observed \in {"none", "complete-file"}

NoPartialExecution ==
    consumer = "running" => dataFuture = "ready" /\ AllReceived

FailurePropagation ==
    dataFuture = "failed" => consumer \in {"blocked", "dep_failed"}

NoPrematurePublication ==
    dataFuture = "ready" => stage = "ready" /\ AllReceived

TerminalResultConsistency ==
    consumer = "done" => observed = "complete-file" /\ dataFuture = "ready"

=============================================================================
SPECIFICATION Spec

INVARIANTS
    TypeOK
    NoPartialExecution
    FailurePropagation
    NoPrematurePublication
    TerminalResultConsistency
