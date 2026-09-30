--------------------------- MODULE ParslContentFilePipeline ---------------------------
EXTENDS Naturals, Integers, FiniteSets, Sequences

(***************************************************************************
 * Small cross-layer pipeline for one Parsl task.
 *
 * The task payload contains a callable/object snapshot and a file input is
 * staged as two chunks.  Source objects may change after submission, but the
 * worker must execute the captured versions.  File visibility is atomic:
 * the worker is admitted only after both chunks have been received.
 ***************************************************************************)

CONSTANTS MAX_VERSION, CHUNKS

TaskStates == {"ready", "queued", "running", "done"}
PayloadStates == {"none", "encoded", "sent", "decoded"}
FileStates == {"absent", "staging", "available"}
ChunkStates == {"none", "sent", "received"}
FutureStates == {"unresolved", "resolved"}

VersionToken(v) == IF v = 0 THEN "v0" ELSE "v1"
ResultToken(fv, iv) == VersionToken(fv) \o ":" \o VersionToken(iv)

VARIABLES taskState, payloadState, sourceFunctionVersion,
          capturedFunctionVersion, sourceFileVersion, capturedFileVersion,
          fileState, chunkState, availableFileVersion,
          futureState, resultToken, observedToken

vars == <<taskState, payloadState, sourceFunctionVersion,
          capturedFunctionVersion, sourceFileVersion, capturedFileVersion,
          fileState, chunkState, availableFileVersion,
          futureState, resultToken, observedToken>>

Init ==
    /\ MAX_VERSION = 1
    /\ CHUNKS = {"c1", "c2"}
    /\ taskState = "ready"
    /\ payloadState = "none"
    /\ sourceFunctionVersion = 0
    /\ capturedFunctionVersion = -1
    /\ sourceFileVersion = 0
    /\ capturedFileVersion = -1
    /\ fileState = "absent"
    /\ chunkState = [c \in CHUNKS |-> "none"]
    /\ availableFileVersion = -1
    /\ futureState = "unresolved"
    /\ resultToken = "none"
    /\ observedToken = "none"

Submit ==
    /\ taskState = "ready"
    /\ taskState' = "queued"
    /\ UNCHANGED <<payloadState, sourceFunctionVersion,
                    capturedFunctionVersion, sourceFileVersion,
                    capturedFileVersion, fileState, chunkState,
                    availableFileVersion, futureState, resultToken,
                    observedToken>>

SerializePayload ==
    /\ taskState = "queued"
    /\ payloadState = "none"
    /\ payloadState' = "encoded"
    /\ capturedFunctionVersion' = sourceFunctionVersion
    /\ UNCHANGED <<taskState, sourceFunctionVersion, sourceFileVersion,
                    capturedFileVersion, fileState, chunkState,
                    availableFileVersion, futureState, resultToken,
                    observedToken>>

SendPayload ==
    /\ payloadState = "encoded"
    /\ payloadState' = "sent"
    /\ UNCHANGED <<taskState, sourceFunctionVersion,
                    capturedFunctionVersion, sourceFileVersion,
                    capturedFileVersion, fileState, chunkState,
                    availableFileVersion, futureState, resultToken,
                    observedToken>>

DecodePayload ==
    /\ payloadState = "sent"
    /\ payloadState' = "decoded"
    /\ UNCHANGED <<taskState, sourceFunctionVersion,
                    capturedFunctionVersion, sourceFileVersion,
                    capturedFileVersion, fileState, chunkState,
                    availableFileVersion, futureState, resultToken,
                    observedToken>>

BeginStageIn ==
    /\ payloadState = "decoded"
    /\ fileState = "absent"
    /\ fileState' = "staging"
    /\ capturedFileVersion' = sourceFileVersion
    /\ chunkState' = [c \in CHUNKS |-> "none"]
    /\ UNCHANGED <<taskState, payloadState, sourceFunctionVersion,
                    capturedFunctionVersion, sourceFileVersion,
                    availableFileVersion, futureState, resultToken,
                    observedToken>>

SendChunk(c) ==
    /\ fileState = "staging"
    /\ c \in CHUNKS
    /\ chunkState[c] = "none"
    /\ chunkState' = [chunkState EXCEPT ![c] = "sent"]
    /\ UNCHANGED <<taskState, payloadState, sourceFunctionVersion,
                    capturedFunctionVersion, sourceFileVersion,
                    capturedFileVersion, fileState, availableFileVersion,
                    futureState, resultToken, observedToken>>

ReceiveChunk(c) ==
    /\ fileState = "staging"
    /\ c \in CHUNKS
    /\ chunkState[c] = "sent"
    /\ chunkState' = [chunkState EXCEPT ![c] = "received"]
    /\ UNCHANGED <<taskState, payloadState, sourceFunctionVersion,
                    capturedFunctionVersion, sourceFileVersion,
                    capturedFileVersion, fileState, availableFileVersion,
                    futureState, resultToken, observedToken>>

PublishFile ==
    /\ fileState = "staging"
    /\ \A c \in CHUNKS : chunkState[c] = "received"
    /\ fileState' = "available"
    /\ availableFileVersion' = capturedFileVersion
    /\ UNCHANGED <<taskState, payloadState, sourceFunctionVersion,
                    capturedFunctionVersion, sourceFileVersion,
                    capturedFileVersion, chunkState, futureState,
                    resultToken, observedToken>>

MutateSources ==
    /\ sourceFunctionVersion < MAX_VERSION
    /\ sourceFileVersion < MAX_VERSION
    /\ sourceFunctionVersion' = sourceFunctionVersion + 1
    /\ sourceFileVersion' = sourceFileVersion + 1
    /\ UNCHANGED <<taskState, payloadState, capturedFunctionVersion,
                    capturedFileVersion, fileState, chunkState,
                    availableFileVersion, futureState, resultToken,
                    observedToken>>

StartWorker ==
    /\ payloadState = "decoded"
    /\ fileState = "available"
    /\ taskState = "queued"
    /\ taskState' = "running"
    /\ UNCHANGED <<payloadState, sourceFunctionVersion,
                    capturedFunctionVersion, sourceFileVersion,
                    capturedFileVersion, fileState, chunkState,
                    availableFileVersion, futureState, resultToken,
                    observedToken>>

CompleteWorker ==
    /\ taskState = "running"
    /\ resultToken' = ResultToken(availableFileVersion,
                                   capturedFunctionVersion)
    /\ taskState' = "done"
    /\ UNCHANGED <<payloadState, sourceFunctionVersion,
                    capturedFunctionVersion, sourceFileVersion,
                    capturedFileVersion, fileState, chunkState,
                    availableFileVersion, futureState, observedToken>>

DeliverResult ==
    /\ taskState = "done"
    /\ futureState = "unresolved"
    /\ futureState' = "resolved"
    /\ observedToken' = resultToken
    /\ UNCHANGED <<taskState, payloadState, sourceFunctionVersion,
                    capturedFunctionVersion, sourceFileVersion,
                    capturedFileVersion, fileState, chunkState,
                    availableFileVersion, resultToken>>

Next ==
    \/ Submit
    \/ SerializePayload
    \/ SendPayload
    \/ DecodePayload
    \/ BeginStageIn
    \/ \E c \in CHUNKS : SendChunk(c) \/ ReceiveChunk(c)
    \/ PublishFile
    \/ MutateSources
    \/ StartWorker
    \/ CompleteWorker
    \/ DeliverResult
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ taskState \in TaskStates
    /\ payloadState \in PayloadStates
    /\ sourceFunctionVersion \in 0..MAX_VERSION
    /\ capturedFunctionVersion \in -1..MAX_VERSION
    /\ sourceFileVersion \in 0..MAX_VERSION
    /\ capturedFileVersion \in -1..MAX_VERSION
    /\ fileState \in FileStates
    /\ chunkState \in [CHUNKS -> ChunkStates]
    /\ availableFileVersion \in -1..MAX_VERSION
    /\ futureState \in FutureStates
    /\ resultToken \in {"none", "v0:v0", "v0:v1", "v1:v0", "v1:v1"}
    /\ observedToken \in {"none", "v0:v0", "v0:v1", "v1:v0", "v1:v1"}

PayloadSnapshotSafety ==
    payloadState = "decoded" =>
        capturedFunctionVersion \in 0..MAX_VERSION

FileAtomicity ==
    fileState = "available" =>
        /\ availableFileVersion = capturedFileVersion
        /\ \A c \in CHUNKS : chunkState[c] = "received"

ExecutionAdmission ==
    taskState \in {"running", "done"} =>
        /\ payloadState = "decoded"
        /\ fileState = "available"

ResultContentSafety ==
    futureState = "resolved" =>
        /\ taskState = "done"
        /\ observedToken = ResultToken(availableFileVersion,
                                         capturedFunctionVersion)

SourceMutationIsolation ==
    futureState = "resolved" =>
        /\ capturedFunctionVersion <= sourceFunctionVersion
        /\ capturedFileVersion <= sourceFileVersion

=============================================================================
CONSTANTS
    MAX_VERSION = 1
    CHUNKS = {"c1", "c2"}

SPECIFICATION Spec

INVARIANTS
    TypeOK
    PayloadSnapshotSafety
    FileAtomicity
    ExecutionAdmission
    ResultContentSafety
    SourceMutationIsolation
