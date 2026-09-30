---------------- MODULE ParslProviderExecutorTimedMonitoring ----------------
EXTENDS Naturals

(***************************************************************************
 * A compact provider/executor/monitoring boundary.
 *
 * A provider block and manager create one physical worker slot for a logical
 * task.  Provider or heartbeat loss moves the logical task to retry_wait,
 * while the old physical attempt can still report.  Monitoring is an
 * asynchronous terminal event and is persisted separately from the Future.
 ***************************************************************************)

CONSTANTS MAX_TIME, HEARTBEAT_TIMEOUT, TASK_TIMEOUT, MAX_RETRIES,
          MAX_PROVIDER_RETRIES, MAX_DB_FAILURES, USE_FIXED

ProviderStates == {"down", "pending", "active", "failed"}
ManagerStates == {"absent", "up", "expired"}
TaskStates == {"pending", "running", "retry_wait", "succeeded", "failed"}
Causes == {"none", "provider_lost", "manager_lost", "timeout"}
LateStates == {"none", "accepted", "stale"}
MonitorStates == {"none", "queued", "persisted"}
Statuses == {"none", "succeeded", "failed"}

VARIABLES now, provider, manager, lastHeartbeat, slots, task, attempts,
          providerRetries, deadline, inFlight, oldInFlight, cause, lateResult,
          monitorState, monitorStatus, dbStatus, dbFailures,
          generation, polledGeneration, stalePoll

vars == <<now, provider, manager, lastHeartbeat, slots, task, attempts,
           providerRetries, deadline, inFlight, oldInFlight, cause, lateResult,
           monitorState, monitorStatus, dbStatus, dbFailures,
           generation, polledGeneration, stalePoll>>

Init ==
    /\ MAX_TIME >= 3
    /\ HEARTBEAT_TIMEOUT > 0
    /\ TASK_TIMEOUT > 0
    /\ MAX_RETRIES >= 0
    /\ MAX_PROVIDER_RETRIES >= 0
    /\ MAX_DB_FAILURES >= 0
    /\ USE_FIXED \in BOOLEAN
    /\ now = 0
    /\ provider = "down"
    /\ manager = "absent"
    /\ lastHeartbeat = 0
    /\ slots = 0
    /\ task = "pending"
    /\ attempts = 0
    /\ providerRetries = 0
    /\ deadline = 0
    /\ inFlight = FALSE
    /\ oldInFlight = FALSE
    /\ cause = "none"
    /\ lateResult = "none"
    /\ monitorState = "none"
    /\ monitorStatus = "none"
    /\ dbStatus = "none"
    /\ dbFailures = 0
    /\ generation = 0
    /\ polledGeneration = 0
    /\ stalePoll = FALSE

Tick ==
    /\ now < MAX_TIME
    /\ now' = now + 1
    /\ UNCHANGED <<provider, manager, lastHeartbeat, slots, task, attempts,
                    providerRetries, deadline, inFlight, oldInFlight, cause,
                    lateResult, monitorState, monitorStatus, dbStatus,
                    dbFailures>>

Heartbeat ==
    /\ manager = "up"
    /\ lastHeartbeat' = now
    /\ UNCHANGED <<now, provider, manager, slots, task, attempts,
                    providerRetries, deadline, inFlight, oldInFlight, cause,
                    lateResult, monitorState, monitorStatus, dbStatus,
                    dbFailures>>

RequestBlock ==
    /\ provider = "down"
    /\ provider' = "pending"
    /\ UNCHANGED <<now, manager, lastHeartbeat, slots, task, attempts,
                    providerRetries, deadline, inFlight, oldInFlight, cause,
                    lateResult, monitorState, monitorStatus, dbStatus,
                    dbFailures>>

ProvisionBlock ==
    /\ provider = "pending"
    /\ provider' = "active"
    /\ UNCHANGED <<now, manager, lastHeartbeat, slots, task, attempts,
                    providerRetries, deadline, inFlight, oldInFlight, cause,
                    lateResult, monitorState, monitorStatus, dbStatus,
                    dbFailures>>

RegisterManager ==
    /\ provider = "active"
    /\ manager = "absent"
    /\ manager' = "up"
    /\ slots' = 1
    /\ lastHeartbeat' = now
    /\ UNCHANGED <<now, provider, task, attempts, providerRetries, deadline,
                    inFlight, oldInFlight, cause, lateResult, monitorState,
                    monitorStatus, dbStatus, dbFailures>>

Submit ==
    /\ provider = "active"
    /\ manager = "up"
    /\ slots > 0
    /\ task = "pending"
    /\ task' = "running"
    /\ slots' = slots - 1
    /\ deadline' = now + TASK_TIMEOUT
    /\ inFlight' = TRUE
    /\ UNCHANGED <<now, provider, manager, lastHeartbeat, attempts,
                    providerRetries, oldInFlight, cause, lateResult,
                    monitorState, monitorStatus, dbStatus, dbFailures>>

Complete ==
    /\ task = "running"
    /\ inFlight
    /\ manager = "up"
    /\ now < deadline
    /\ task' = "succeeded"
    /\ slots' = slots + 1
    /\ inFlight' = FALSE
    /\ UNCHANGED <<now, provider, manager, lastHeartbeat, attempts,
                    providerRetries, deadline, oldInFlight, cause, lateResult,
                    monitorState, monitorStatus, dbStatus, dbFailures>>

Timeout ==
    /\ task = "running"
    /\ inFlight
    /\ now >= deadline
    /\ task' = "retry_wait"
    /\ cause' = "timeout"
    /\ oldInFlight' = TRUE
    /\ inFlight' = FALSE
    /\ slots' = 1
    /\ UNCHANGED <<now, provider, manager, lastHeartbeat, attempts,
                    providerRetries, deadline, lateResult, monitorState,
                    monitorStatus, dbStatus, dbFailures>>

ExpireManager ==
    /\ manager = "up"
    /\ now - lastHeartbeat >= HEARTBEAT_TIMEOUT
    /\ manager' = "expired"
    /\ task' = IF task = "running" THEN "retry_wait" ELSE task
    /\ cause' = IF task = "running" THEN "manager_lost" ELSE cause
    /\ oldInFlight' = IF task = "running" THEN TRUE ELSE oldInFlight
    /\ inFlight' = IF task = "running" THEN FALSE ELSE inFlight
    /\ slots' = IF task = "running" THEN 1 ELSE slots
    /\ UNCHANGED <<now, provider, lastHeartbeat, attempts, providerRetries,
                    deadline, lateResult, monitorState, monitorStatus,
                    dbStatus, dbFailures>>

FailProvider ==
    /\ provider = "active"
    /\ provider' = "failed"
    /\ manager' = "expired"
    /\ task' = IF task = "running" THEN "retry_wait" ELSE task
    /\ cause' = IF task = "running" THEN "provider_lost" ELSE cause
    /\ oldInFlight' = IF task = "running" THEN TRUE ELSE oldInFlight
    /\ inFlight' = IF task = "running" THEN FALSE ELSE inFlight
    /\ slots' = 0
    /\ UNCHANGED <<now, lastHeartbeat, attempts, providerRetries, deadline,
                    lateResult, monitorState, monitorStatus, dbStatus,
                    dbFailures>>

RetryProvision ==
    /\ provider = "failed"
    /\ providerRetries < MAX_PROVIDER_RETRIES
    /\ provider' = "pending"
    /\ manager' = "absent"
    /\ slots' = 0
    /\ providerRetries' = providerRetries + 1
    /\ UNCHANGED <<now, lastHeartbeat, task, attempts, deadline, inFlight,
                    oldInFlight, cause, lateResult, monitorState,
                    monitorStatus, dbStatus, dbFailures>>

RetryLost ==
    /\ task = "retry_wait"
    /\ attempts < MAX_RETRIES
    /\ provider = "active"
    /\ manager = "up"
    /\ task' = "pending"
    /\ attempts' = attempts + 1
    /\ cause' = "none"
    /\ UNCHANGED <<now, provider, manager, lastHeartbeat, slots, providerRetries,
                    deadline,
                    inFlight, oldInFlight, lateResult, monitorState,
                    monitorStatus, dbStatus, dbFailures>>

RejectAfterRetry ==
    /\ task = "retry_wait"
    /\ attempts = MAX_RETRIES
    /\ task' = "failed"
    /\ UNCHANGED <<now, provider, manager, lastHeartbeat, slots, attempts,
                    providerRetries, deadline, inFlight, oldInFlight, cause,
                    lateResult, monitorState, monitorStatus, dbStatus,
                    dbFailures>>

LateComplete ==
    /\ oldInFlight
    /\ task \in {"retry_wait", "pending", "running", "succeeded", "failed"}
    /\ IF USE_FIXED
          THEN /\ lateResult' = "stale"
               /\ UNCHANGED task
          ELSE /\ lateResult' = "accepted"
               /\ task' = "succeeded"
    /\ oldInFlight' = FALSE
    /\ UNCHANGED <<now, provider, manager, lastHeartbeat, slots, attempts,
                    providerRetries, deadline, inFlight, cause, monitorState,
                    monitorStatus, dbStatus, dbFailures>>

EmitStatus ==
    /\ task \in {"succeeded", "failed"}
    /\ monitorState = "none"
    /\ monitorState' = "queued"
    /\ monitorStatus' = task
    /\ UNCHANGED <<now, provider, manager, lastHeartbeat, slots, task,
                    attempts, providerRetries, deadline, inFlight, oldInFlight,
                    cause, lateResult, dbStatus, dbFailures>>

FailDatabaseWrite ==
    /\ monitorState = "queued"
    /\ dbFailures < MAX_DB_FAILURES
    /\ dbFailures' = dbFailures + 1
    /\ UNCHANGED <<now, provider, manager, lastHeartbeat, slots, task,
                    attempts, providerRetries, deadline, inFlight, oldInFlight,
                    cause, lateResult, monitorState, monitorStatus, dbStatus>>

PersistStatus ==
    /\ monitorState = "queued"
    /\ monitorState' = "persisted"
    /\ dbStatus' = monitorStatus
    /\ UNCHANGED <<now, provider, manager, lastHeartbeat, slots, task,
                    attempts, providerRetries, deadline, inFlight, oldInFlight,
                    cause, lateResult, monitorStatus, dbFailures>>

ProvisionGeneration ==
    /\ provider = "active"
    /\ generation = polledGeneration
    /\ generation < 2
    /\ generation' = generation + 1
    /\ stalePoll' = FALSE
    /\ UNCHANGED <<now, provider, manager, lastHeartbeat, slots, task,
                    attempts, providerRetries, deadline, inFlight, oldInFlight,
                    cause, lateResult, monitorState, monitorStatus, dbStatus,
                    dbFailures, polledGeneration>>

LatePoll ==
    /\ provider = "failed"
    /\ polledGeneration < generation
    /\ stalePoll' = TRUE
    /\ provider' = IF USE_FIXED THEN provider ELSE "active"
    /\ UNCHANGED <<now, manager, lastHeartbeat, slots, task, attempts,
                    providerRetries, deadline, inFlight, oldInFlight, cause,
                    lateResult, monitorState, monitorStatus, dbStatus,
                    dbFailures, generation, polledGeneration>>

CoreNext ==
    \/ Tick \/ Heartbeat \/ RequestBlock \/ ProvisionBlock \/ RegisterManager
    \/ Submit \/ Complete \/ Timeout \/ ExpireManager \/ FailProvider
    \/ RetryProvision \/ RetryLost \/ RejectAfterRetry \/ LateComplete
    \/ EmitStatus \/ FailDatabaseWrite \/ PersistStatus
    \/ UNCHANGED vars

Next ==
    \/ (CoreNext /\ UNCHANGED <<generation, polledGeneration, stalePoll>>)
    \/ ProvisionGeneration
    \/ LatePoll

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ now \in 0..MAX_TIME
    /\ provider \in ProviderStates
    /\ manager \in ManagerStates
    /\ lastHeartbeat \in 0..MAX_TIME
    /\ slots \in 0..1
    /\ task \in TaskStates
    /\ attempts \in 0..MAX_RETRIES
    /\ providerRetries \in 0..MAX_PROVIDER_RETRIES
    /\ deadline \in 0..(MAX_TIME + TASK_TIMEOUT)
    /\ inFlight \in BOOLEAN
    /\ oldInFlight \in BOOLEAN
    /\ cause \in Causes
    /\ lateResult \in LateStates
    /\ monitorState \in MonitorStates
    /\ monitorStatus \in Statuses
    /\ dbStatus \in Statuses
    /\ dbFailures \in 0..MAX_DB_FAILURES
    /\ generation \in 0..2
    /\ polledGeneration \in 0..2
    /\ stalePoll \in BOOLEAN

AdmissionSafety ==
    task = "running" => provider = "active" /\ manager = "up" /\ slots = 0

CapacitySafety == provider # "active" => slots = 0
RetryBoundSafety == attempts <= MAX_RETRIES
ProviderRetryBoundSafety == providerRetries <= MAX_PROVIDER_RETRIES
TerminalCauseSafety == cause # "none" => task # "succeeded"
StaleResultSafety == lateResult = "accepted" => ~USE_FIXED

MonitoringSafety ==
    /\ monitorState = "persisted" => task \in {"succeeded", "failed"}
    /\ dbStatus = "succeeded" => task = "succeeded"
    /\ dbStatus = "failed" => task = "failed"

DatabaseRetryBound == dbFailures <= MAX_DB_FAILURES
ProviderGenerationBound == generation <= 2
StalePollSafety == stalePoll => ~(provider = "active" /\ manager = "expired" /\ slots = 0)

=============================================================================
