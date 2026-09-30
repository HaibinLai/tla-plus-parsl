------------------------- MODULE ParslJoinFileStaging -------------------------
EXTENDS Naturals, FiniteSets

(***************************************************************************
 * File-content readiness for a join task.
 *
 * A two-chunk source is transferred before the logical task can run.  The
 * source may change or a received chunk may become corrupt before publication.
 * The fixed branch publishes only a complete, checksummed snapshot and then
 * permits join execution; the Current branch exposes unsafe publication.
 *************************************************************************** *)

CONSTANT USE_FIXED
Chunks == 1..2
Versions == 0..1
ChunkStates == {"missing", "received"}
ChecksumStates == {"missing", "valid", "corrupt"}
TaskStates == {"pending", "running", "done"}
OuterStates == {"joining", "succeeded"}

VARIABLES sourceVersion, capturedVersion, chunkState, checksum,
          dataReady, task, outer
vars == <<sourceVersion, capturedVersion, chunkState, checksum,
           dataReady, task, outer>>

Init ==
    /\ sourceVersion = 0
    /\ capturedVersion = 0
    /\ chunkState = [c \in Chunks |-> "missing"]
    /\ checksum = [c \in Chunks |-> "missing"]
    /\ dataReady = FALSE
    /\ task = "pending"
    /\ outer = "joining"

ReceiveChunk(c) ==
    /\ c \in Chunks
    /\ chunkState[c] = "missing"
    /\ chunkState' = [chunkState EXCEPT ![c] = "received"]
    /\ checksum' = [checksum EXCEPT ![c] = "valid"]
    /\ UNCHANGED <<sourceVersion, capturedVersion, dataReady, task, outer>>

CorruptChunk(c) ==
    /\ c \in Chunks
    /\ ~dataReady
    /\ chunkState[c] = "received"
    /\ checksum' = [checksum EXCEPT ![c] = "corrupt"]
    /\ dataReady' = FALSE
    /\ UNCHANGED <<sourceVersion, capturedVersion, chunkState, task, outer>>

RepairChunk(c) ==
    /\ c \in Chunks
    /\ c \in {d \in Chunks: checksum[d] = "corrupt"}
    /\ checksum' = [checksum EXCEPT ![c] = "valid"]
    /\ UNCHANGED <<sourceVersion, capturedVersion, chunkState,
                    dataReady, task, outer>>

ChangeSource ==
    /\ ~dataReady
    /\ sourceVersion' = 1 - sourceVersion
    /\ UNCHANGED <<capturedVersion, chunkState, checksum,
                    dataReady, task, outer>>

PublishData ==
    /\ \A c \in Chunks: chunkState[c] = "received"
    /\ IF USE_FIXED
          THEN /\ \A c \in Chunks: checksum[c] = "valid"
               /\ capturedVersion = sourceVersion
          ELSE TRUE
    /\ dataReady' = TRUE
    /\ capturedVersion' = sourceVersion
    /\ UNCHANGED <<sourceVersion, chunkState, checksum, task, outer>>

StartTask ==
    /\ dataReady
    /\ task = "pending"
    /\ task' = "running"
    /\ UNCHANGED <<sourceVersion, capturedVersion, chunkState, checksum,
                    dataReady, outer>>

CompleteTask ==
    /\ task = "running"
    /\ task' = "done"
    /\ UNCHANGED <<sourceVersion, capturedVersion, chunkState, checksum,
                    dataReady, outer>>

FinalizeJoin ==
    /\ task = "done"
    /\ outer' = "succeeded"
    /\ UNCHANGED <<sourceVersion, capturedVersion, chunkState, checksum,
                    dataReady, task>>

Next ==
    \/ \E c \in Chunks: ReceiveChunk(c) \/ CorruptChunk(c) \/ RepairChunk(c)
    \/ ChangeSource \/ PublishData \/ StartTask \/ CompleteTask \/ FinalizeJoin
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ sourceVersion \in Versions
    /\ capturedVersion \in Versions
    /\ chunkState \in [Chunks -> ChunkStates]
    /\ checksum \in [Chunks -> ChecksumStates]
    /\ dataReady \in BOOLEAN
    /\ task \in TaskStates
    /\ outer \in OuterStates

ReadinessSafety == task \in {"running", "done"} => dataReady
ContentSafety == dataReady => \A c \in Chunks: checksum[c] = "valid"
VersionSafety == dataReady => capturedVersion = sourceVersion
JoinSafety == outer = "succeeded" => task = "done"

=============================================================================
