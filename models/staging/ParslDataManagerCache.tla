--------------------------- MODULE ParslDataManagerCache ---------------------------
EXTENDS Naturals, Integers

(***************************************************************************
 * A small DataManager stage-in cache model.
 *
 * A transfer captures the source content version before copying.  The source
 * may change while the temporary buffer is being filled.  The unsafe branch
 * publishes that old buffer as ready; the fixed branch rejects it and retries
 * from the current source version.  Consumers are admitted only after an
 * atomically published, version-matching cache entry exists.
 ***************************************************************************)

CONSTANTS MAX_RETRIES, USE_FIXED

CacheStates == {"empty", "staging", "failed", "ready"}
ConsumerStates == {"waiting", "running", "done"}

VARIABLES sourceVersion, cacheState, capturedVersion, cacheVersion,
          transferPhase, attempt, consumerA, consumerB

vars == <<sourceVersion, cacheState, capturedVersion, cacheVersion,
           transferPhase, attempt, consumerA, consumerB>>

Init ==
    /\ MAX_RETRIES >= 1
    /\ USE_FIXED \in BOOLEAN
    /\ sourceVersion = 0
    /\ cacheState = "empty"
    /\ capturedVersion = -1
    /\ cacheVersion = -1
    /\ transferPhase = "none"
    /\ attempt = 0
    /\ consumerA = "waiting"
    /\ consumerB = "waiting"

StartStage ==
    /\ cacheState \in {"empty", "failed"}
    /\ transferPhase = "none"
    /\ cacheState' = "staging"
    /\ capturedVersion' = sourceVersion
    /\ transferPhase' = "copying"
    /\ UNCHANGED <<sourceVersion, cacheVersion, attempt, consumerA, consumerB>>

SourceMutatesDuringStage ==
    /\ cacheState = "staging"
    /\ sourceVersion = 0
    /\ sourceVersion' = 1
    /\ UNCHANGED <<cacheState, capturedVersion, cacheVersion,
                    transferPhase, attempt, consumerA, consumerB>>

CopyComplete ==
    /\ cacheState = "staging"
    /\ transferPhase = "copying"
    /\ transferPhase' = "publishable"
    /\ UNCHANGED <<sourceVersion, cacheState, capturedVersion, cacheVersion,
                    attempt, consumerA, consumerB>>

PublishFresh ==
    /\ transferPhase = "publishable"
    /\ capturedVersion = sourceVersion
    /\ cacheState' = "ready"
    /\ cacheVersion' = capturedVersion
    /\ transferPhase' = "none"
    /\ UNCHANGED <<sourceVersion, capturedVersion, attempt, consumerA, consumerB>>

PublishStaleCurrent ==
    /\ ~USE_FIXED
    /\ transferPhase = "publishable"
    /\ capturedVersion # sourceVersion
    /\ cacheState' = "ready"
    /\ cacheVersion' = capturedVersion
    /\ transferPhase' = "none"
    /\ UNCHANGED <<sourceVersion, capturedVersion, attempt, consumerA, consumerB>>

RejectStaleFixed ==
    /\ USE_FIXED
    /\ transferPhase = "publishable"
    /\ capturedVersion # sourceVersion
    /\ cacheState' = "failed"
    /\ transferPhase' = "none"
    /\ UNCHANGED <<sourceVersion, capturedVersion, cacheVersion,
                    attempt, consumerA, consumerB>>

RetryStage ==
    /\ cacheState = "failed"
    /\ attempt < MAX_RETRIES
    /\ cacheState' = "empty"
    /\ attempt' = attempt + 1
    /\ UNCHANGED <<sourceVersion, capturedVersion, cacheVersion,
                    transferPhase, consumerA, consumerB>>

StartConsumerA ==
    /\ consumerA = "waiting"
    /\ cacheState = "ready"
    /\ cacheVersion = sourceVersion
    /\ consumerA' = "running"
    /\ UNCHANGED <<sourceVersion, cacheState, capturedVersion, cacheVersion,
                    transferPhase, attempt, consumerB>>

StartConsumerB ==
    /\ consumerB = "waiting"
    /\ cacheState = "ready"
    /\ cacheVersion = sourceVersion
    /\ consumerB' = "running"
    /\ UNCHANGED <<sourceVersion, cacheState, capturedVersion, cacheVersion,
                    transferPhase, attempt, consumerA>>

FinishConsumerA ==
    /\ consumerA = "running"
    /\ consumerA' = "done"
    /\ UNCHANGED <<sourceVersion, cacheState, capturedVersion, cacheVersion,
                    transferPhase, attempt, consumerB>>

FinishConsumerB ==
    /\ consumerB = "running"
    /\ consumerB' = "done"
    /\ UNCHANGED <<sourceVersion, cacheState, capturedVersion, cacheVersion,
                    transferPhase, attempt, consumerA>>

Next ==
    \/ StartStage
    \/ SourceMutatesDuringStage
    \/ CopyComplete
    \/ PublishFresh
    \/ PublishStaleCurrent
    \/ RejectStaleFixed
    \/ RetryStage
    \/ StartConsumerA
    \/ StartConsumerB
    \/ FinishConsumerA
    \/ FinishConsumerB
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ sourceVersion \in 0..1
    /\ cacheState \in CacheStates
    /\ capturedVersion \in -1..1
    /\ cacheVersion \in -1..1
    /\ transferPhase \in {"none", "copying", "publishable"}
    /\ attempt \in 0..MAX_RETRIES
    /\ consumerA \in ConsumerStates
    /\ consumerB \in ConsumerStates

AtomicCacheSafety ==
    cacheState = "ready" => cacheVersion = sourceVersion

ConsumerAdmissionSafety ==
    (consumerA # "waiting" => cacheState = "ready")
    /\ (consumerB # "waiting" => cacheState = "ready")

RetryBound == attempt <= MAX_RETRIES

TerminalConsumerSafety ==
    (consumerA = "done" => consumerA # "waiting")
    /\ (consumerB = "done" => consumerB # "waiting")

=============================================================================
