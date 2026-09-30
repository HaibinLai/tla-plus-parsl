--------------------------- MODULE ParslPipeline ---------------------------
EXTENDS Naturals, FiniteSets

(***************************************************************************
 * Compact cross-layer Parsl pipeline.
 *
 * One logical task crosses callable payload serialization, a physical worker
 * attempt, result correlation, chunked output stage-out, DataFuture readiness,
 * and monitoring persistence.  USE_FIXED controls the two intentionally
 * unsafe boundaries: an old result may resolve the Future, and stage-out or
 * monitoring may become visible before all output chunks are published.
 ***************************************************************************)

CONSTANTS CHUNKS, MAX_RETRIES, USE_FIXED

Attempts == 0..MAX_RETRIES
TaskStates == {"new", "queued", "running", "retry_wait", "done", "failed"}
PayloadStates == {"none", "encoded", "decoded", "invalid"}
AttemptStates == {"none", "running", "failed", "done", "stale"}
ResultStates == {"none", "queued", "accepted", "stale"}
StageStates == {"idle", "sending", "ready"}
ChunkStates == {"none", "sent", "received"}
FutureStates == {"unresolved", "resolved", "rejected"}
DataFutureStates == {"unresolved", "ready"}
MonitorStates == {"none", "queued", "persisted"}

VARIABLES task, payload, currentAttempt, attemptState, resultState,
          future, stage, chunks, dataFuture, monitor, monitorDB
vars == <<task, payload, currentAttempt, attemptState, resultState,
          future, stage, chunks, dataFuture, monitor, monitorDB>>

Init ==
    /\ CHUNKS # {}
    /\ MAX_RETRIES >= 0
    /\ USE_FIXED \in BOOLEAN
    /\ task = "new"
    /\ payload = "none"
    /\ currentAttempt = 0
    /\ attemptState = [k \in Attempts |-> "none"]
    /\ resultState = [k \in Attempts |-> "none"]
    /\ future = "unresolved"
    /\ stage = "idle"
    /\ chunks = [c \in CHUNKS |-> "none"]
    /\ dataFuture = "unresolved"
    /\ monitor = "none"
    /\ monitorDB = "none"

Submit ==
    /\ task = "new"
    /\ task' = "queued"
    /\ UNCHANGED <<payload, currentAttempt, attemptState, resultState,
                    future, stage, chunks, dataFuture, monitor, monitorDB>>

EncodePayload ==
    /\ task = "queued"
    /\ payload = "none"
    /\ payload' = "encoded"
    /\ UNCHANGED <<task, currentAttempt, attemptState, resultState,
                    future, stage, chunks, dataFuture, monitor, monitorDB>>

DecodePayload ==
    /\ task = "queued"
    /\ payload = "encoded"
    /\ payload' = "decoded"
    /\ UNCHANGED <<task, currentAttempt, attemptState, resultState,
                    future, stage, chunks, dataFuture, monitor, monitorDB>>

StartAttempt ==
    /\ task = "queued"
    /\ payload = "decoded"
    /\ attemptState[currentAttempt] = "none"
    /\ task' = "running"
    /\ attemptState' = [attemptState EXCEPT ![currentAttempt] = "running"]
    /\ UNCHANGED <<payload, currentAttempt, resultState, future, stage,
                    chunks, dataFuture, monitor, monitorDB>>

CompleteAttempt ==
    /\ task = "running"
    /\ attemptState[currentAttempt] = "running"
    /\ task' = "done"
    /\ attemptState' = [attemptState EXCEPT ![currentAttempt] = "done"]
    /\ resultState' = [resultState EXCEPT ![currentAttempt] = "queued"]
    /\ UNCHANGED <<payload, currentAttempt, future, stage, chunks,
                    dataFuture, monitor, monitorDB>>

FailAttempt ==
    /\ task = "running"
    /\ attemptState[currentAttempt] = "running"
    /\ attemptState' = [attemptState EXCEPT ![currentAttempt] = "failed"]
    /\ task' = IF currentAttempt < MAX_RETRIES THEN "retry_wait" ELSE "failed"
    /\ future' = IF currentAttempt < MAX_RETRIES THEN future ELSE "rejected"
    /\ UNCHANGED <<payload, currentAttempt, resultState, stage, chunks,
                    dataFuture, monitor, monitorDB>>

RetryAttempt ==
    /\ task = "retry_wait"
    /\ currentAttempt < MAX_RETRIES
    /\ currentAttempt' = currentAttempt + 1
    /\ task' = "queued"
    /\ payload' = "none"
    /\ UNCHANGED <<attemptState, resultState, future, stage, chunks,
                    dataFuture, monitor, monitorDB>>

LateResult(k) ==
    /\ k \in Attempts
    /\ attemptState[k] = "failed"
    /\ resultState[k] = "none"
    /\ resultState' = [resultState EXCEPT ![k] = "queued"]
    /\ UNCHANGED <<task, payload, currentAttempt, attemptState, future,
                    stage, chunks, dataFuture, monitor, monitorDB>>

DeliverResult(k) ==
    /\ k \in Attempts
    /\ resultState[k] = "queued"
    /\ IF k = currentAttempt /\ attemptState[k] = "done"
       THEN /\ resultState' = [resultState EXCEPT ![k] = "accepted"]
            /\ future' = "resolved"
       ELSE IF USE_FIXED
            THEN /\ resultState' = [resultState EXCEPT ![k] = "stale"]
                 /\ future' = future
            ELSE /\ resultState' = [resultState EXCEPT ![k] = "accepted"]
                 /\ future' = "resolved"
    /\ UNCHANGED <<task, payload, currentAttempt, attemptState, stage,
                    chunks, dataFuture, monitor, monitorDB>>

StartStageOut ==
    /\ future = "resolved"
    /\ stage = "idle"
    /\ stage' = "sending"
    /\ chunks' = [c \in CHUNKS |-> "none"]
    /\ UNCHANGED <<task, payload, currentAttempt, attemptState, resultState,
                    future, dataFuture, monitor, monitorDB>>

SendChunk(c) ==
    /\ stage = "sending"
    /\ c \in CHUNKS
    /\ chunks[c] = "none"
    /\ chunks' = [chunks EXCEPT ![c] = "sent"]
    /\ UNCHANGED <<task, payload, currentAttempt, attemptState, resultState,
                    future, stage, dataFuture, monitor, monitorDB>>

ReceiveChunk(c) ==
    /\ stage = "sending"
    /\ c \in CHUNKS
    /\ chunks[c] = "sent"
    /\ chunks' = [chunks EXCEPT ![c] = "received"]
    /\ UNCHANGED <<task, payload, currentAttempt, attemptState, resultState,
                    future, stage, dataFuture, monitor, monitorDB>>

AllReceived == \A c \in CHUNKS : chunks[c] = "received"
SomeReceived == \E c \in CHUNKS : chunks[c] = "received"

PublishStageOut ==
    /\ stage = "sending"
    /\ IF USE_FIXED THEN AllReceived ELSE SomeReceived
    /\ stage' = "ready"
    /\ dataFuture' = "ready"
    /\ UNCHANGED <<task, payload, currentAttempt, attemptState, resultState,
                    future, chunks, monitor, monitorDB>>

EmitMonitor ==
    /\ task = "done"
    /\ monitor = "none"
    /\ IF USE_FIXED THEN dataFuture = "ready" ELSE TRUE
    /\ monitor' = "queued"
    /\ UNCHANGED <<task, payload, currentAttempt, attemptState, resultState,
                    future, stage, chunks, dataFuture, monitorDB>>

PersistMonitor ==
    /\ monitor = "queued"
    /\ monitor' = "persisted"
    /\ monitorDB' = "persisted"
    /\ UNCHANGED <<task, payload, currentAttempt, attemptState, resultState,
                    future, stage, chunks, dataFuture>>

Next ==
    \/ Submit
    \/ EncodePayload
    \/ DecodePayload
    \/ StartAttempt
    \/ CompleteAttempt
    \/ FailAttempt
    \/ RetryAttempt
    \/ \E k \in Attempts : LateResult(k) \/ DeliverResult(k)
    \/ StartStageOut
    \/ \E c \in CHUNKS : SendChunk(c) \/ ReceiveChunk(c)
    \/ PublishStageOut
    \/ EmitMonitor
    \/ PersistMonitor
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ task \in TaskStates
    /\ payload \in PayloadStates
    /\ currentAttempt \in Attempts
    /\ attemptState \in [Attempts -> AttemptStates]
    /\ resultState \in [Attempts -> ResultStates]
    /\ future \in FutureStates
    /\ stage \in StageStates
    /\ chunks \in [CHUNKS -> ChunkStates]
    /\ dataFuture \in DataFutureStates
    /\ monitor \in MonitorStates
    /\ monitorDB \in MonitorStates

SerializationAdmission ==
    task \in {"running", "done"} => payload = "decoded"

RetryBound == currentAttempt <= MAX_RETRIES

ResultSafety ==
    /\ future = "resolved" => attemptState[currentAttempt] = "done"
    /\ \A k \in Attempts : resultState[k] = "stale" =>
          ~(k = currentAttempt /\ attemptState[k] = "done")

StageSafety ==
    dataFuture = "ready" =>
        /\ future = "resolved"
        /\ stage = "ready"
        /\ AllReceived

MonitoringSafety ==
    monitorDB = "persisted" =>
        /\ task = "done"
        /\ dataFuture = "ready"

WorkerAdmissionSafety ==
    task = "running" => attemptState[currentAttempt] = "running"

=============================================================================
