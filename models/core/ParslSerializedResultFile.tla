--------------------------- MODULE ParslSerializedResultFile ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Minimal result-file publication protocol.
 *
 * Executors serialize a TaskResult into a result file.  The file may be
 * written in two symbolic chunks.  The current branch permits a consumer to
 * observe publication while the worker is still writing; USE_FIXED requires
 * the complete serialized payload and a completed attempt before publication.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES attemptState, chunksWritten, fileState, futureState
vars == <<attemptState, chunksWritten, fileState, futureState>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ attemptState = "running"
    /\ chunksWritten = 0
    /\ fileState = "hidden"
    /\ futureState = "unresolved"

WriteChunk ==
    /\ attemptState = "running"
    /\ chunksWritten < 2
    /\ chunksWritten' = chunksWritten + 1
    /\ fileState' = "partial"
    /\ UNCHANGED <<attemptState, futureState>>

CompleteAttempt ==
    /\ attemptState = "running"
    /\ chunksWritten = 2
    /\ attemptState' = "done"
    /\ UNCHANGED <<chunksWritten, fileState, futureState>>

PublishFile ==
    /\ attemptState \in {"running", "done"}
    /\ chunksWritten > 0
    /\ IF USE_FIXED
          THEN /\ chunksWritten = 2
               /\ attemptState = "done"
          ELSE TRUE
    /\ fileState' = "published"
    /\ UNCHANGED <<attemptState, chunksWritten, futureState>>

ConsumeResult ==
    /\ fileState = "published"
    /\ futureState = "unresolved"
    /\ futureState' = "resolved"
    /\ UNCHANGED <<attemptState, chunksWritten, fileState>>

Next == WriteChunk \/ CompleteAttempt \/ PublishFile \/ ConsumeResult \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ attemptState \in {"running", "done"}
    /\ chunksWritten \in 0..2
    /\ fileState \in {"hidden", "partial", "published"}
    /\ futureState \in {"unresolved", "resolved"}

PublicationSafety ==
    fileState = "published" =>
        /\ chunksWritten = 2
        /\ attemptState = "done"

ConsumptionSafety ==
    futureState = "resolved" => fileState = "published"

=============================================================================
