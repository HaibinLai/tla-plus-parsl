------------------------- MODULE ParslJoinStageRetry -------------------------
EXTENDS Naturals, Integers, FiniteSets, Sequences

(***************************************************************************
 * A small cross-layer join model.
 *
 * Each logical dependency has physical attempts.  An attempt stages a
 * two-chunk input, publishes it atomically, runs a worker, and sends a
 * correlated result.  The outer join may complete only from the current
 * successful attempt of every dependency.  The Current branch intentionally
 * permits checksum-blind publication and stale result admission so TLC can
 * expose the corresponding safety violations.
 ***************************************************************************)

CONSTANT USE_FIXED, MAX_RETRIES
DEPS == {"A", "B"}
CHUNKS == 1..2
VERSIONS == 0..1

LogicalStates == {"pending", "staging", "running", "retry_wait", "succeeded", "failed"}
StageStates == {"none", "partial", "published", "stale"}
ChunkStates == {"missing", "received", "corrupt"}
WireStates == {"none", "queued", "consumed"}
OuterStates == {"joining", "succeeded", "failed"}

VARIABLES sourceVersion, currentAttempt, logicalState, stageState,
          chunkState, capturedVersion, wire, wireVersion,
          staleAccepted, outerState, outerResult
vars == <<sourceVersion, currentAttempt, logicalState, stageState,
           chunkState, capturedVersion, wire, wireVersion,
           staleAccepted, outerState, outerResult>>

Init ==
    /\ sourceVersion = [d \in DEPS |-> 0]
    /\ currentAttempt = [d \in DEPS |-> 0]
    /\ logicalState = [d \in DEPS |-> "pending"]
    /\ stageState = [d \in DEPS |-> [a \in 0..MAX_RETRIES |-> "none"]]
    /\ chunkState = [d \in DEPS |->
          [a \in 0..MAX_RETRIES |-> [c \in CHUNKS |-> "missing"]]]
    /\ capturedVersion = [d \in DEPS |-> [a \in 0..MAX_RETRIES |-> (-1)]]
    /\ wire = [d \in DEPS |-> [a \in 0..MAX_RETRIES |-> "none"]]
    /\ wireVersion = [d \in DEPS |-> [a \in 0..MAX_RETRIES |-> (-1)]]
    /\ staleAccepted = [d \in DEPS |-> FALSE]
    /\ outerState = "joining"
    /\ outerResult = <<>>

StartStage(d) ==
    /\ logicalState[d] \in {"pending", "retry_wait"}
    /\ stageState[d][currentAttempt[d]] = "none"
    /\ stageState' = [stageState EXCEPT ![d][currentAttempt[d]] = "partial"]
    /\ chunkState' = [chunkState EXCEPT
          ![d][currentAttempt[d]] = [c \in CHUNKS |-> "missing"]]
    /\ capturedVersion' = [capturedVersion EXCEPT
          ![d][currentAttempt[d]] = sourceVersion[d]]
    /\ logicalState' = [logicalState EXCEPT ![d] = "staging"]
    /\ UNCHANGED <<sourceVersion, currentAttempt, wire, wireVersion,
                    staleAccepted,
                    outerState, outerResult>>

ReceiveChunk(d, c) ==
    /\ logicalState[d] = "staging"
    /\ c \in CHUNKS
    /\ chunkState[d][currentAttempt[d]][c] = "missing"
    /\ chunkState' = [chunkState EXCEPT
          ![d][currentAttempt[d]][c] = "received"]
    /\ UNCHANGED <<sourceVersion, currentAttempt, logicalState, stageState,
                    capturedVersion, wire, wireVersion, staleAccepted,
                    outerState, outerResult>>

CorruptChunk(d, c) ==
    /\ logicalState[d] = "staging"
    /\ c \in CHUNKS
    /\ chunkState[d][currentAttempt[d]][c] = "received"
    /\ chunkState' = [chunkState EXCEPT
          ![d][currentAttempt[d]][c] = "corrupt"]
    /\ UNCHANGED <<sourceVersion, currentAttempt, logicalState, stageState,
                    capturedVersion, wire, wireVersion, staleAccepted,
                    outerState, outerResult>>

Publish(d) ==
    /\ logicalState[d] = "staging"
    /\ \A c \in CHUNKS : chunkState[d][currentAttempt[d]][c] = "received"
    /\ IF USE_FIXED
          THEN \A c \in CHUNKS : chunkState[d][currentAttempt[d]][c] # "corrupt"
          ELSE TRUE
    /\ stageState' = [stageState EXCEPT
          ![d][currentAttempt[d]] = "published"]
    /\ logicalState' = [logicalState EXCEPT ![d] = "running"]
    /\ UNCHANGED <<sourceVersion, currentAttempt, chunkState,
                    capturedVersion, wire, wireVersion, staleAccepted,
                    outerState, outerResult>>

Complete(d) ==
    /\ logicalState[d] = "running"
    /\ stageState[d][currentAttempt[d]] = "published"
    /\ wire' = [wire EXCEPT ![d][currentAttempt[d]] = "queued"]
    /\ wireVersion' = [wireVersion EXCEPT
          ![d][currentAttempt[d]] = capturedVersion[d][currentAttempt[d]]]
    /\ UNCHANGED <<sourceVersion, currentAttempt, logicalState, stageState,
                    chunkState, capturedVersion, staleAccepted,
                    outerState, outerResult>>

Fail(d) ==
    /\ logicalState[d] = "running"
    /\ stageState' = [stageState EXCEPT
          ![d][currentAttempt[d]] = "stale"]
    /\ logicalState' = [logicalState EXCEPT ![d] =
          IF currentAttempt[d] < MAX_RETRIES THEN "retry_wait" ELSE "failed"]
    /\ UNCHANGED <<sourceVersion, currentAttempt, chunkState,
                    capturedVersion, wire, wireVersion, staleAccepted,
                    outerState, outerResult>>

Retry(d) ==
    /\ logicalState[d] = "retry_wait"
    /\ currentAttempt[d] < MAX_RETRIES
    /\ currentAttempt' = [currentAttempt EXCEPT ![d] = @ + 1]
    /\ logicalState' = [logicalState EXCEPT ![d] = "pending"]
    /\ UNCHANGED <<sourceVersion, stageState, chunkState, capturedVersion,
                    wire, wireVersion, staleAccepted, outerState, outerResult>>

LateComplete(d, a) ==
    /\ a < currentAttempt[d]
    /\ stageState[d][a] = "stale"
    /\ wire[d][a] = "none"
    /\ wire' = [wire EXCEPT ![d][a] = "queued"]
    /\ wireVersion' = [wireVersion EXCEPT ![d][a] = capturedVersion[d][a]]
    /\ UNCHANGED <<sourceVersion, currentAttempt, logicalState, stageState,
                    chunkState, capturedVersion, staleAccepted,
                    outerState, outerResult>>

Deliver(d, a) ==
    /\ wire[d][a] = "queued"
    /\ wire' = [wire EXCEPT ![d][a] = "consumed"]
    /\ logicalState' = IF a = currentAttempt[d] /\ stageState[d][a] = "published"
          THEN [logicalState EXCEPT ![d] = "succeeded"]
          ELSE IF USE_FIXED
               THEN logicalState
               ELSE [logicalState EXCEPT ![d] = "succeeded"]
    /\ staleAccepted' = IF a = currentAttempt[d] /\ stageState[d][a] = "published"
          THEN staleAccepted
          ELSE IF USE_FIXED
               THEN staleAccepted
               ELSE [staleAccepted EXCEPT ![d] = TRUE]
    /\ UNCHANGED <<sourceVersion, currentAttempt, stageState, chunkState,
                    capturedVersion, wireVersion, outerState, outerResult>>

Finalize ==
    /\ outerState = "joining"
    /\ \A d \in DEPS : logicalState[d] = "succeeded"
    /\ outerState' = "succeeded"
    /\ outerResult' = [d \in DEPS |-> wireVersion[d][currentAttempt[d]]]
    /\ UNCHANGED <<sourceVersion, currentAttempt, logicalState, stageState,
                    chunkState, capturedVersion, wire, wireVersion,
                    staleAccepted>>

PropagateFailure ==
    /\ outerState = "joining"
    /\ \E d \in DEPS : logicalState[d] = "failed"
    /\ outerState' = "failed"
    /\ outerResult' = <<>>
    /\ UNCHANGED <<sourceVersion, currentAttempt, logicalState, stageState,
                    chunkState, capturedVersion, wire, wireVersion,
                    staleAccepted>>

Next ==
    \/ \E d \in DEPS : StartStage(d) \/ Publish(d) \/ Complete(d) \/ Fail(d) \/ Retry(d)
    \/ \E d \in DEPS, c \in CHUNKS : ReceiveChunk(d, c) \/ CorruptChunk(d, c)
    \/ \E d \in DEPS, a \in 0..MAX_RETRIES : LateComplete(d, a) \/ Deliver(d, a)
    \/ Finalize \/ PropagateFailure
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ sourceVersion \in [DEPS -> VERSIONS]
    /\ currentAttempt \in [DEPS -> 0..MAX_RETRIES]
    /\ logicalState \in [DEPS -> LogicalStates]
    /\ stageState \in [DEPS -> [0..MAX_RETRIES -> StageStates]]
    /\ chunkState \in [DEPS -> [0..MAX_RETRIES -> [CHUNKS -> ChunkStates]]]
    /\ capturedVersion \in [DEPS -> [0..MAX_RETRIES -> (-1)..1]]
    /\ wire \in [DEPS -> [0..MAX_RETRIES -> WireStates]]
    /\ wireVersion \in [DEPS -> [0..MAX_RETRIES -> (-1)..1]]
    /\ staleAccepted \in [DEPS -> BOOLEAN]
    /\ outerState \in OuterStates
    /\ outerResult \in ([DEPS -> (-1)..1] \cup {<<>>})

AdmissionSafety ==
    \A d \in DEPS : logicalState[d] \in {"running", "succeeded"}
        => stageState[d][currentAttempt[d]] = "published"

RetryBound == \A d \in DEPS : currentAttempt[d] <= MAX_RETRIES

JoinSafety == outerState = "succeeded" =>
    \A d \in DEPS : logicalState[d] = "succeeded"

StaleResultSafety ==
    \A d \in DEPS : ~staleAccepted[d]

=============================================================================
