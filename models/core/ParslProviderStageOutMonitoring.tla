------------------------- MODULE ParslProviderStageOutMonitoring -------------------------
EXTENDS Naturals, FiniteSets

(***************************************************************************
 * Provider loss, stage-out publication, retry, and monitoring composition.
 *
 * A provider can disappear while an output transfer is still delivering
 * bytes.  Reprovisioning creates a new physical attempt; the Fixed branch
 * requires both the provider generation and logical attempt to match before
 * publishing a terminal task result.  The Current branch admits the old
 * transfer and persists a false success.
 ***************************************************************************)

CONSTANTS CHUNKS, MAX_RETRIES, USE_FIXED
ATTEMPTS == 0..MAX_RETRIES
ProviderStates == {"active", "lost"}
TaskStates == {"pending", "running", "retry_wait", "succeeded", "failed"}
StageStates == {"idle", "sending", "published", "stale"}
ChunkStates == {"none", "received"}
MonitorStates == {"none", "queued", "persisted"}

VARIABLES provider, currentAttempt, task, stage, chunks,
          monitor, monitorStatus, staleAccepted
vars == <<provider, currentAttempt, task, stage, chunks,
           monitor, monitorStatus, staleAccepted>>

Init ==
    /\ CHUNKS # {}
    /\ MAX_RETRIES >= 1
    /\ USE_FIXED \in BOOLEAN
    /\ provider = "active"
    /\ currentAttempt = 0
    /\ task = "pending"
    /\ stage = [a \in ATTEMPTS |-> "idle"]
    /\ chunks = [a \in ATTEMPTS |-> [c \in CHUNKS |-> "none"]]
    /\ monitor = "none"
    /\ monitorStatus = "none"
    /\ staleAccepted = FALSE

Start ==
    /\ provider = "active"
    /\ task \in {"pending", "retry_wait"}
    /\ stage[currentAttempt] = "idle"
    /\ stage' = [stage EXCEPT ![currentAttempt] = "sending"]
    /\ task' = "running"
    /\ UNCHANGED <<provider, currentAttempt, chunks, monitor, monitorStatus,
                    staleAccepted>>

Receive(c) ==
    /\ task = "running"
    /\ c \in CHUNKS
    /\ chunks[currentAttempt][c] = "none"
    /\ chunks' = [chunks EXCEPT ![currentAttempt][c] = "received"]
    /\ UNCHANGED <<provider, currentAttempt, task, stage, monitor,
                    monitorStatus, staleAccepted>>

ProviderLost ==
    /\ provider = "active"
    /\ task = "running"
    /\ provider' = "lost"
    /\ task' = IF currentAttempt < MAX_RETRIES THEN "retry_wait" ELSE "failed"
    /\ stage' = [stage EXCEPT ![currentAttempt] = "stale"]
    /\ UNCHANGED <<currentAttempt, chunks, monitor, monitorStatus, staleAccepted>>

Reprovision ==
    /\ provider = "lost"
    /\ provider' = "active"
    /\ UNCHANGED <<currentAttempt, task, stage, chunks, monitor, monitorStatus,
                    staleAccepted>>

Retry ==
    /\ provider = "active"
    /\ task = "retry_wait"
    /\ currentAttempt < MAX_RETRIES
    /\ currentAttempt' = currentAttempt + 1
    /\ task' = "pending"
    /\ stage' = [stage EXCEPT ![currentAttempt + 1] = "idle"]
    /\ chunks' = [chunks EXCEPT
          ![currentAttempt + 1] = [c \in CHUNKS |-> "none"]]
    /\ UNCHANGED <<provider, monitor, monitorStatus, staleAccepted>>

Publish(a) ==
    /\ a \in ATTEMPTS
    /\ stage[a] \in {"sending", "stale"}
    /\ \A c \in CHUNKS : chunks[a][c] = "received"
    /\ IF USE_FIXED THEN provider = "active" /\ a = currentAttempt ELSE TRUE
    /\ stage' = [stage EXCEPT ![a] = "published"]
    /\ UNCHANGED <<provider, currentAttempt, task, chunks, monitor,
                    monitorStatus, staleAccepted>>

Finish(a) ==
    /\ a \in ATTEMPTS
    /\ stage[a] = "published"
    /\ task \in {"pending", "retry_wait", "running"}
    /\ IF USE_FIXED THEN provider = "active" /\ a = currentAttempt ELSE TRUE
    /\ task' = "succeeded"
    /\ staleAccepted' = IF a = currentAttempt /\ provider = "active"
          THEN staleAccepted ELSE TRUE
    /\ UNCHANGED <<provider, currentAttempt, stage, chunks, monitor,
                    monitorStatus>>

QueueMonitor ==
    /\ task \in {"succeeded", "failed"}
    /\ monitor = "none"
    /\ monitor' = "queued"
    /\ monitorStatus' = IF task = "succeeded" THEN "succeeded" ELSE "failed"
    /\ UNCHANGED <<provider, currentAttempt, task, stage, chunks, staleAccepted>>

PersistMonitor ==
    /\ monitor = "queued"
    /\ monitor' = "persisted"
    /\ UNCHANGED <<provider, currentAttempt, task, stage, chunks,
                    monitorStatus, staleAccepted>>

Next ==
    \/ Start
    \/ \E c \in CHUNKS : Receive(c)
    \/ ProviderLost
    \/ Reprovision
    \/ Retry
    \/ \E a \in ATTEMPTS : Publish(a) \/ Finish(a)
    \/ QueueMonitor
    \/ PersistMonitor
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ provider \in ProviderStates
    /\ currentAttempt \in ATTEMPTS
    /\ task \in TaskStates
    /\ stage \in [ATTEMPTS -> StageStates]
    /\ chunks \in [ATTEMPTS -> [CHUNKS -> ChunkStates]]
    /\ monitor \in MonitorStates
    /\ monitorStatus \in {"none", "succeeded", "failed"}
    /\ staleAccepted \in BOOLEAN

RetryBound == currentAttempt <= MAX_RETRIES
PublicationSafety == task = "succeeded" => provider = "active" /\ stage[currentAttempt] = "published"
MonitoringSafety == monitor = "persisted" => task \in {"succeeded", "failed"}
StaleSafety == ~staleAccepted
=============================================================================
