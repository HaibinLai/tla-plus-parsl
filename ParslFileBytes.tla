--------------------------- MODULE ParslFileBytes ---------------------------
EXTENDS Naturals, Integers, Sequences, FiniteSets

(***************************************************************************
 * A bounded file-content model.
 *
 * File contents are represented by symbolic byte strings, one per chunk.  A
 * transfer carries the bytes and a checksum through a wire state.  The
 * receiver writes a temporary buffer first; availability/transferred becomes
 * visible only after every chunk has passed checksum validation and an atomic
 * publish action runs.
 ***************************************************************************)

CONSTANTS FILES, CHUNKS, FILE_CHUNKS, MAX_VERSION

PHASES == {"absent", "staging", "available", "stale", "stageout", "transferred"}
WIRE_STATES == {"none", "sent", "received", "corrupt"}
ChunkIds == FILE_CHUNKS

ChunkSet(f) == {c \in CHUNKS : (f \o "::" \o c) \in FILE_CHUNKS}
ChunkId(f, c) == f \o "::" \o c
Content(f, c, v) == ChunkId(f, c) \o
    (IF v = 0 THEN ":bytes:v0" ELSE ":bytes:v1")
InitialContent(x) == x \o ":bytes:v0"
Checksum(token) == token \o ":checksum"
NoContent == "none"

VARIABLES phase, sourceVersion, capturedVersion, sourceToken,
          wireState, wireToken, wireChecksum,
          bufferToken, bufferChecksum, availableToken,
          visibleToken

vars == <<phase, sourceVersion, capturedVersion, sourceToken,
           wireState, wireToken, wireChecksum,
           bufferToken, bufferChecksum, availableToken, visibleToken>>

Init ==
    /\ FILES # {}
    /\ CHUNKS # {}
    /\ FILE_CHUNKS \subseteq {f \o "::" \o c : f \in FILES, c \in CHUNKS}
    /\ \A f \in FILES : ChunkSet(f) # {}
    /\ MAX_VERSION > 0
    /\ phase = [f \in FILES |-> "absent"]
    /\ sourceVersion = [f \in FILES |-> 0]
    /\ capturedVersion = [f \in FILES |-> (-1)]
    /\ sourceToken = [x \in ChunkIds |-> InitialContent(x)]
    /\ wireState = [x \in ChunkIds |-> "none"]
    /\ wireToken = [x \in ChunkIds |-> NoContent]
    /\ wireChecksum = [x \in ChunkIds |-> NoContent]
    /\ bufferToken = [x \in ChunkIds |-> NoContent]
    /\ bufferChecksum = [x \in ChunkIds |-> NoContent]
    /\ availableToken = [x \in ChunkIds |-> NoContent]
    /\ visibleToken = [x \in ChunkIds |-> NoContent]

TransferComplete(f) ==
    \A c \in ChunkSet(f) :
        wireState[ChunkId(f, c)] = "received"
        /\ wireToken[ChunkId(f, c)] # NoContent
        /\ wireChecksum[ChunkId(f, c)] = Checksum(wireToken[ChunkId(f, c)])
        /\ bufferToken[ChunkId(f, c)] = wireToken[ChunkId(f, c)]
        /\ bufferChecksum[ChunkId(f, c)] = wireChecksum[ChunkId(f, c)]

ResetTransfer(f) ==
    /\ wireState' = [x \in ChunkIds |-> "none"]
    /\ wireToken' = [x \in ChunkIds |-> NoContent]
    /\ wireChecksum' = [x \in ChunkIds |-> NoContent]
    /\ bufferToken' = [x \in ChunkIds |-> NoContent]
    /\ bufferChecksum' = [x \in ChunkIds |-> NoContent]

BeginStageIn(f) ==
    /\ phase[f] = "absent"
    /\ phase' = [phase EXCEPT ![f] = "staging"]
    /\ capturedVersion' = [capturedVersion EXCEPT ![f] = sourceVersion[f]]
    /\ UNCHANGED <<sourceVersion, sourceToken, availableToken, visibleToken>>
    /\ ResetTransfer(f)

BeginStageOut(f) ==
    /\ phase[f] = "available"
    /\ phase' = [phase EXCEPT ![f] = "stageout"]
    /\ UNCHANGED <<sourceVersion, capturedVersion, sourceToken,
                    availableToken, visibleToken>>
    /\ ResetTransfer(f)

SendChunk(f, c) ==
    /\ phase[f] \in {"staging", "stageout"}
    /\ c \in ChunkSet(f)
    /\ wireState[ChunkId(f, c)] = "none"
    /\ LET x == ChunkId(f, c)
           token == IF phase[f] = "staging"
                    THEN sourceToken[x]
                    ELSE availableToken[x]
       IN
           /\ token # NoContent
           /\ wireState' = [wireState EXCEPT ![x] = "sent"]
           /\ wireToken' = [wireToken EXCEPT ![x] = token]
           /\ wireChecksum' = [wireChecksum EXCEPT ![x] = Checksum(token)]
    /\ UNCHANGED <<phase, sourceVersion, capturedVersion, sourceToken,
                    bufferToken, bufferChecksum, availableToken, visibleToken>>

CorruptChunk(f, c) ==
    /\ phase[f] \in {"staging", "stageout"}
    /\ c \in ChunkSet(f)
    /\ wireState[ChunkId(f, c)] = "sent"
    /\ LET x == ChunkId(f, c) IN
        /\ wireState' = [wireState EXCEPT ![x] = "corrupt"]
        /\ wireToken' = [wireToken EXCEPT ![x] = wireToken[x] \o ":corrupt"]
    /\ UNCHANGED <<phase, sourceVersion, capturedVersion, sourceToken,
                    wireChecksum, bufferToken, bufferChecksum,
                    availableToken, visibleToken>>

ReceiveChunk(f, c) ==
    /\ phase[f] \in {"staging", "stageout"}
    /\ c \in ChunkSet(f)
    /\ wireState[ChunkId(f, c)] = "sent"
    /\ LET x == ChunkId(f, c) IN
        /\ wireChecksum[x] = Checksum(wireToken[x])
        /\ wireState' = [wireState EXCEPT ![x] = "received"]
        /\ bufferToken' = [bufferToken EXCEPT ![x] = wireToken[x]]
        /\ bufferChecksum' = [bufferChecksum EXCEPT ![x] = wireChecksum[x]]
    /\ UNCHANGED <<phase, sourceVersion, capturedVersion, sourceToken,
                    wireToken, wireChecksum, availableToken, visibleToken>>

RejectCorruptChunk(f, c) ==
    /\ phase[f] \in {"staging", "stageout"}
    /\ c \in ChunkSet(f)
    /\ wireState[ChunkId(f, c)] = "sent"
    /\ wireChecksum[ChunkId(f, c)] # Checksum(wireToken[ChunkId(f, c)])
    /\ wireState' = [wireState EXCEPT ![ChunkId(f, c)] = "corrupt"]
    /\ UNCHANGED <<phase, sourceVersion, capturedVersion, sourceToken,
                    wireToken, wireChecksum, bufferToken, bufferChecksum,
                    availableToken, visibleToken>>

RepairChunk(f, c) ==
    /\ phase[f] \in {"staging", "stageout"}
    /\ c \in ChunkSet(f)
    /\ wireState[ChunkId(f, c)] = "corrupt"
    /\ LET x == ChunkId(f, c) IN
        /\ wireState' = [wireState EXCEPT ![x] = "none"]
        /\ wireToken' = [wireToken EXCEPT ![x] = NoContent]
        /\ wireChecksum' = [wireChecksum EXCEPT ![x] = NoContent]
    /\ UNCHANGED <<phase, sourceVersion, capturedVersion, sourceToken,
                    bufferToken, bufferChecksum, availableToken, visibleToken>>

PublishStageIn(f) ==
    /\ phase[f] = "staging"
    /\ TransferComplete(f)
    /\ capturedVersion[f] = sourceVersion[f]
    /\ phase' = [phase EXCEPT ![f] = "available"]
    /\ availableToken' = [x \in ChunkIds |->
          IF x \in {ChunkId(f, c) : c \in ChunkSet(f)}
          THEN bufferToken[x] ELSE availableToken[x]]
    /\ UNCHANGED <<sourceVersion, capturedVersion, sourceToken,
                    wireState, wireToken, wireChecksum,
                    bufferToken, bufferChecksum, visibleToken>>

RejectStaleStageIn(f) ==
    /\ phase[f] = "staging"
    /\ TransferComplete(f)
    /\ capturedVersion[f] # sourceVersion[f]
    /\ phase' = [phase EXCEPT ![f] = "stale"]
    /\ UNCHANGED <<sourceVersion, capturedVersion, sourceToken,
                    wireState, wireToken, wireChecksum,
                    bufferToken, bufferChecksum, availableToken, visibleToken>>

RestartStale(f) ==
    /\ phase[f] = "stale"
    /\ phase' = [phase EXCEPT ![f] = "staging"]
    /\ capturedVersion' = [capturedVersion EXCEPT ![f] = sourceVersion[f]]
    /\ UNCHANGED <<sourceVersion, sourceToken, availableToken, visibleToken>>
    /\ ResetTransfer(f)

PublishStageOut(f) ==
    /\ phase[f] = "stageout"
    /\ TransferComplete(f)
    /\ phase' = [phase EXCEPT ![f] = "transferred"]
    /\ visibleToken' = [x \in ChunkIds |->
          IF x \in {ChunkId(f, c) : c \in ChunkSet(f)}
          THEN bufferToken[x] ELSE visibleToken[x]]
    /\ UNCHANGED <<sourceVersion, capturedVersion, sourceToken,
                    wireState, wireToken, wireChecksum,
                    bufferToken, bufferChecksum, availableToken>>

ModifySource(f, c) ==
    /\ phase[f] \in {"absent", "staging", "available"}
    /\ c \in ChunkSet(f)
    /\ sourceVersion[f] < MAX_VERSION
    /\ LET x == ChunkId(f, c)
           newVersion == sourceVersion[f] + 1
       IN
           /\ sourceVersion' = [sourceVersion EXCEPT ![f] = newVersion]
           /\ sourceToken' = [sourceToken EXCEPT ![x] = Content(f, c, newVersion)]
    /\ UNCHANGED <<phase, capturedVersion, wireState, wireToken, wireChecksum,
                    bufferToken, bufferChecksum, availableToken, visibleToken>>

Next ==
    \/ \E f \in FILES : BeginStageIn(f) \/ BeginStageOut(f)
    \/ \E f \in FILES, c \in CHUNKS : SendChunk(f, c)
    \/ \E f \in FILES, c \in CHUNKS : CorruptChunk(f, c)
    \/ \E f \in FILES, c \in CHUNKS : ReceiveChunk(f, c)
    \/ \E f \in FILES, c \in CHUNKS : RejectCorruptChunk(f, c)
    \/ \E f \in FILES, c \in CHUNKS : RepairChunk(f, c)
    \/ \E f \in FILES : PublishStageIn(f) \/ RejectStaleStageIn(f)
    \/ \E f \in FILES : RestartStale(f) \/ PublishStageOut(f)
    \/ \E f \in FILES, c \in CHUNKS : ModifySource(f, c)
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ phase \in [FILES -> PHASES]
    /\ sourceVersion \in [FILES -> 0..MAX_VERSION]
    /\ capturedVersion \in [FILES -> (-1)..MAX_VERSION]
    /\ sourceToken \in [ChunkIds -> STRING]
    /\ wireState \in [ChunkIds -> WIRE_STATES]
    /\ wireToken \in [ChunkIds -> STRING]
    /\ wireChecksum \in [ChunkIds -> STRING]
    /\ bufferToken \in [ChunkIds -> STRING]
    /\ bufferChecksum \in [ChunkIds -> STRING]
    /\ availableToken \in [ChunkIds -> STRING]
    /\ visibleToken \in [ChunkIds -> STRING]

ChecksumSafety ==
    \A x \in ChunkIds :
        wireState[x] = "received"
        => /\ wireChecksum[x] = Checksum(wireToken[x])
           /\ bufferChecksum[x] = Checksum(bufferToken[x])
           /\ bufferToken[x] = wireToken[x]

NoPrematurePublish ==
    \A f \in FILES :
        phase[f] \in {"available", "transferred"}
        => \A c \in ChunkSet(f) :
             availableToken[ChunkId(f, c)] # NoContent

AtomicOutputPublish ==
    \A f \in FILES :
        visibleToken[ChunkId(f, CHOOSE c \in ChunkSet(f) : TRUE)] # NoContent
        => phase[f] = "transferred"

StaleTransferSafety ==
    \A f \in FILES : phase[f] = "stale" => capturedVersion[f] # sourceVersion[f]

NoCorruptPublish ==
    \A f \in FILES : phase[f] = "transferred"
        => \A c \in ChunkSet(f) :
             visibleToken[ChunkId(f, c)] # NoContent
             /\ visibleToken[ChunkId(f, c)] = bufferToken[ChunkId(f, c)]

=============================================================================
