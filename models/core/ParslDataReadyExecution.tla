--------------------------- MODULE ParslDataReadyExecution ---------------------------
EXTENDS Naturals, Integers, Sequences

(***************************************************************************
 * Small cross-layer data-readiness model.
 *
 * A stage-in transfer captures a source version, moves two symbolic chunks
 * through a wire/buffer, and publishes a DataFuture only after all chunks are
 * received.  A dependent logical task may execute only after that Future is
 * ready.  If the source changes during transfer, the current branch publishes
 * the captured old version; the fixed branch marks it stale and retries.
 ***************************************************************************)

CONSTANTS CHUNKS, USE_FIXED

TransferStates == {"absent", "staging", "ready", "stale"}
ChunkStates == {"none", "sent", "received", "corrupt"}
TaskStates == {"blocked", "queued", "running", "done"}

VARIABLES transfer, capturedVersion, sourceVersion, publishedVersion,
          chunkState, taskState, observedVersion
vars == <<transfer, capturedVersion, sourceVersion, publishedVersion,
          chunkState, taskState, observedVersion>>

AllReceived == \A c \in CHUNKS : chunkState[c] = "received"

Init ==
    /\ CHUNKS # {}
    /\ USE_FIXED \in BOOLEAN
    /\ transfer = "absent"
    /\ capturedVersion = -1
    /\ sourceVersion = 0
    /\ publishedVersion = -1
    /\ chunkState = [c \in CHUNKS |-> "none"]
    /\ taskState = "blocked"
    /\ observedVersion = -1

BeginStageIn ==
    /\ transfer = "absent"
    /\ transfer' = "staging"
    /\ capturedVersion' = sourceVersion
    /\ chunkState' = [c \in CHUNKS |-> "none"]
    /\ UNCHANGED <<sourceVersion, publishedVersion, taskState, observedVersion>>

ModifySource ==
    /\ transfer = "staging"
    /\ sourceVersion = 0
    /\ sourceVersion' = 1
    /\ UNCHANGED <<transfer, capturedVersion, publishedVersion,
                    chunkState, taskState, observedVersion>>

SendChunk(c) ==
    /\ transfer = "staging"
    /\ c \in CHUNKS
    /\ chunkState[c] = "none"
    /\ chunkState' = [chunkState EXCEPT ![c] = "sent"]
    /\ UNCHANGED <<transfer, capturedVersion, sourceVersion,
                    publishedVersion, taskState, observedVersion>>

ReceiveChunk(c) ==
    /\ transfer = "staging"
    /\ c \in CHUNKS
    /\ chunkState[c] = "sent"
    /\ chunkState' = [chunkState EXCEPT ![c] = "received"]
    /\ UNCHANGED <<transfer, capturedVersion, sourceVersion,
                    publishedVersion, taskState, observedVersion>>

CorruptChunk(c) ==
    /\ transfer = "staging"
    /\ c \in CHUNKS
    /\ chunkState[c] = "sent"
    /\ chunkState' = [chunkState EXCEPT ![c] = "corrupt"]
    /\ UNCHANGED <<transfer, capturedVersion, sourceVersion,
                    publishedVersion, taskState, observedVersion>>

RepairChunk(c) ==
    /\ transfer = "staging"
    /\ c \in CHUNKS
    /\ chunkState[c] = "corrupt"
    /\ chunkState' = [chunkState EXCEPT ![c] = "none"]
    /\ UNCHANGED <<transfer, capturedVersion, sourceVersion,
                    publishedVersion, taskState, observedVersion>>

Publish ==
    /\ transfer = "staging"
    /\ AllReceived
    /\ IF USE_FIXED /\ capturedVersion # sourceVersion
          THEN /\ transfer' = "stale"
               /\ UNCHANGED publishedVersion
          ELSE /\ transfer' = "ready"
               /\ publishedVersion' = capturedVersion
    /\ UNCHANGED <<capturedVersion, sourceVersion, chunkState,
                    taskState, observedVersion>>

RetryStale ==
    /\ transfer = "stale"
    /\ transfer' = "staging"
    /\ capturedVersion' = sourceVersion
    /\ chunkState' = [c \in CHUNKS |-> "none"]
    /\ UNCHANGED <<sourceVersion, publishedVersion, taskState, observedVersion>>

SubmitDependentTask ==
    /\ transfer = "ready"
    /\ taskState = "blocked"
    /\ taskState' = "queued"
    /\ UNCHANGED <<transfer, capturedVersion, sourceVersion, publishedVersion,
                    chunkState, observedVersion>>

StartTask ==
    /\ taskState = "queued"
    /\ transfer = "ready"
    /\ taskState' = "running"
    /\ UNCHANGED <<transfer, capturedVersion, sourceVersion, publishedVersion,
                    chunkState, observedVersion>>

CompleteTask ==
    /\ taskState = "running"
    /\ taskState' = "done"
    /\ observedVersion' = publishedVersion
    /\ UNCHANGED <<transfer, capturedVersion, sourceVersion, publishedVersion,
                    chunkState>>

Next ==
    \/ BeginStageIn
    \/ ModifySource
    \/ \E c \in CHUNKS : SendChunk(c) \/ ReceiveChunk(c) \/ CorruptChunk(c) \/ RepairChunk(c)
    \/ Publish
    \/ RetryStale
    \/ SubmitDependentTask
    \/ StartTask
    \/ CompleteTask
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ transfer \in TransferStates
    /\ capturedVersion \in -1..1
    /\ sourceVersion \in 0..1
    /\ publishedVersion \in -1..1
    /\ chunkState \in [CHUNKS -> ChunkStates]
    /\ taskState \in TaskStates
    /\ observedVersion \in -1..1

DependencySafety ==
    taskState \in {"queued", "running", "done"} => transfer = "ready"

DataVersionSafety ==
    transfer = "ready" => publishedVersion = sourceVersion

NoPrematureExecution ==
    taskState = "running" => transfer = "ready"

ObservedContentSafety ==
    taskState = "done" => observedVersion = sourceVersion

=============================================================================
