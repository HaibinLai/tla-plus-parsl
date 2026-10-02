----------------------- MODULE ParslStageOutExecutorRetry -----------------------
EXTENDS Naturals, FiniteSets

(***************************************************************************
 * Cross-layer stage-out/executor retry boundary.
 *
 * A logical task has physical attempts.  The executor result and the output
 * transfer are independent asynchronous channels: an old stage-out can still
 * publish after the task has entered a retry.  The Current branch admits an
 * old result or old publication; the Fixed branch correlates both with the
 * current attempt and keeps the DataFuture unresolved until publication is
 * complete.
 ***************************************************************************)

CONSTANTS CHUNKS, MAX_RETRIES, USE_FIXED
ATTEMPTS == 0..MAX_RETRIES
TaskStates == {"pending", "running", "retry_wait", "result_wait", "succeeded", "failed"}
StageStates == {"idle", "sending", "published"}
ChunkStates == {"none", "received"}
ResultStates == {"none", "queued", "consumed"}
FutureStates == {"unresolved", "ready", "failed"}
MonitorStates == {"none", "queued", "persisted"}

VARIABLES currentAttempt, task, stage, chunks, result, future,
          monitor, monitorDB, staleAccepted
vars == <<currentAttempt, task, stage, chunks, result, future,
           monitor, monitorDB, staleAccepted>>

Init ==
    /\ CHUNKS # {}
    /\ USE_FIXED \in BOOLEAN
    /\ MAX_RETRIES >= 1
    /\ currentAttempt = 0
    /\ task = "pending"
    /\ stage = [a \in ATTEMPTS |-> "idle"]
    /\ chunks = [a \in ATTEMPTS |-> [c \in CHUNKS |-> "none"]]
    /\ result = [a \in ATTEMPTS |-> "none"]
    /\ future = "unresolved"
    /\ monitor = "none"
    /\ monitorDB = "none"
    /\ staleAccepted = FALSE

Start ==
    /\ task \in {"pending", "retry_wait"}
    /\ stage[currentAttempt] = "idle"
    /\ stage' = [stage EXCEPT ![currentAttempt] = "sending"]
    /\ task' = "running"
    /\ UNCHANGED <<currentAttempt, chunks, result, future, monitor, monitorDB,
                    staleAccepted>>

Send(c) ==
    /\ task = "running"
    /\ c \in CHUNKS
    /\ chunks[currentAttempt][c] = "none"
    /\ chunks' = [chunks EXCEPT ![currentAttempt][c] = "received"]
    /\ UNCHANGED <<currentAttempt, task, stage, result, future, monitor,
                    monitorDB, staleAccepted>>

ExecutorSuccess ==
    /\ task = "running"
    /\ result[currentAttempt] = "none"
    /\ result' = [result EXCEPT ![currentAttempt] = "queued"]
    /\ task' = "result_wait"
    /\ UNCHANGED <<currentAttempt, stage, chunks, future, monitor, monitorDB,
                    staleAccepted>>

ExecutorFailure ==
    /\ task = "running"
    /\ task' = IF currentAttempt < MAX_RETRIES THEN "retry_wait" ELSE "failed"
    /\ future' = IF currentAttempt < MAX_RETRIES THEN future ELSE "failed"
    /\ UNCHANGED <<currentAttempt, stage, chunks, result, monitor, monitorDB,
                    staleAccepted>>

Retry ==
    /\ task = "retry_wait"
    /\ currentAttempt < MAX_RETRIES
    /\ currentAttempt' = currentAttempt + 1
    /\ task' = "pending"
    /\ stage' = [stage EXCEPT ![currentAttempt + 1] = "idle"]
    /\ chunks' = [chunks EXCEPT
          ![currentAttempt + 1] = [c \in CHUNKS |-> "none"]]
    /\ UNCHANGED <<result, future, monitor, monitorDB, staleAccepted>>

Publish(a) ==
    /\ a \in ATTEMPTS
    /\ stage[a] = "sending"
    /\ \A c \in CHUNKS : chunks[a][c] = "received"
    /\ IF USE_FIXED THEN a = currentAttempt ELSE TRUE
    /\ stage' = [stage EXCEPT ![a] = "published"]
    /\ UNCHANGED <<currentAttempt, task, chunks, result, future, monitor,
                    monitorDB, staleAccepted>>

ConsumeResult(a) ==
    /\ a \in ATTEMPTS
    /\ result[a] = "queued"
    /\ result' = [result EXCEPT ![a] = "consumed"]
    /\ IF a = currentAttempt /\ stage[a] = "published"
          THEN /\ task' = "succeeded"
               /\ future' = "ready"
               /\ staleAccepted' = staleAccepted
          ELSE IF USE_FIXED
               THEN /\ task' = task
                    /\ future' = future
                    /\ staleAccepted' = staleAccepted
               ELSE /\ task' = "succeeded"
                    /\ future' = "ready"
                    /\ staleAccepted' = TRUE
    /\ UNCHANGED <<currentAttempt, stage, chunks, monitor, monitorDB>>

QueueMonitor ==
    /\ task \in {"succeeded", "failed"}
    /\ monitor = "none"
    /\ monitor' = "queued"
    /\ UNCHANGED <<currentAttempt, task, stage, chunks, result, future,
                    monitorDB, staleAccepted>>

PersistMonitor ==
    /\ monitor = "queued"
    /\ monitor' = "persisted"
    /\ monitorDB' = "persisted"
    /\ UNCHANGED <<currentAttempt, task, stage, chunks, result, future,
                    staleAccepted>>

Next ==
    \/ Start
    \/ \E c \in CHUNKS : Send(c)
    \/ ExecutorSuccess
    \/ ExecutorFailure
    \/ Retry
    \/ \E a \in ATTEMPTS : Publish(a) \/ ConsumeResult(a)
    \/ QueueMonitor
    \/ PersistMonitor
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ currentAttempt \in ATTEMPTS
    /\ task \in TaskStates
    /\ stage \in [ATTEMPTS -> StageStates]
    /\ chunks \in [ATTEMPTS -> [CHUNKS -> ChunkStates]]
    /\ result \in [ATTEMPTS -> ResultStates]
    /\ future \in FutureStates
    /\ monitor \in MonitorStates
    /\ monitorDB \in MonitorStates
    /\ staleAccepted \in BOOLEAN

RetryBound == currentAttempt <= MAX_RETRIES

PublicationSafety ==
    future = "ready" => stage[currentAttempt] = "published"

ResultAttemptSafety ==
    task = "succeeded" => result[currentAttempt] = "consumed"

StaleResultSafety == ~staleAccepted

MonitoringSafety == monitorDB = "persisted" => task \in {"succeeded", "failed"}

=============================================================================
