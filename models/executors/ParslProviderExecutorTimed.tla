----------------------- MODULE ParslProviderExecutorTimed -----------------------
EXTENDS Naturals

(***************************************************************************
 * Small provider-backed executor lifecycle.
 *
 * One provider block provisions one manager and one worker slot.  A logical
 * task is separate from its physical attempt: provider/manager loss moves the
 * task to lost while the old attempt can still report later.  The current
 * branch accepts that old report; the fixed branch records it as stale.
 *)

CONSTANTS MAX_TIME, HEARTBEAT_TIMEOUT, TASK_TIMEOUT, MAX_RETRIES, USE_FIXED
ProviderStates == {"down", "pending", "active", "failed"}
ManagerStates == {"absent", "up", "expired"}
TaskStates == {"pending", "running", "lost", "done"}
Causes == {"none", "provider_lost", "manager_lost", "timeout"}
LateStates == {"none", "accepted", "stale"}

VARIABLES now, provider, manager, lastHeartbeat, slots, task, attempts,
          deadline, inFlight, oldInFlight, cause, lateResult
vars == <<now, provider, manager, lastHeartbeat, slots, task, attempts,
           deadline, inFlight, oldInFlight, cause, lateResult>>

Init ==
    /\ MAX_TIME >= 3
    /\ HEARTBEAT_TIMEOUT > 0
    /\ TASK_TIMEOUT > 0
    /\ MAX_RETRIES >= 0
    /\ USE_FIXED \in BOOLEAN
    /\ now = 0
    /\ provider = "down"
    /\ manager = "absent"
    /\ lastHeartbeat = 0
    /\ slots = 0
    /\ task = "pending"
    /\ attempts = 0
    /\ deadline = 0
    /\ inFlight = FALSE
    /\ oldInFlight = FALSE
    /\ cause = "none"
    /\ lateResult = "none"

Tick ==
    /\ now < MAX_TIME
    /\ now' = now + 1
    /\ UNCHANGED <<provider, manager, lastHeartbeat, slots, task, attempts,
                    deadline, inFlight, oldInFlight, cause, lateResult>>

Heartbeat ==
    /\ manager = "up"
    /\ lastHeartbeat' = now
    /\ UNCHANGED <<now, provider, manager, slots, task, attempts, deadline,
                    inFlight, oldInFlight, cause, lateResult>>

RequestBlock ==
    /\ provider = "down"
    /\ provider' = "pending"
    /\ UNCHANGED <<now, manager, lastHeartbeat, slots, task, attempts,
                    deadline, inFlight, oldInFlight, cause, lateResult>>

ProvisionBlock ==
    /\ provider = "pending"
    /\ provider' = "active"
    /\ UNCHANGED <<now, manager, lastHeartbeat, slots, task, attempts,
                    deadline, inFlight, oldInFlight, cause, lateResult>>

RegisterManager ==
    /\ provider = "active"
    /\ manager = "absent"
    /\ manager' = "up"
    /\ slots' = 1
    /\ lastHeartbeat' = now
    /\ UNCHANGED <<now, provider, task, attempts, deadline, inFlight,
                    oldInFlight, cause, lateResult>>

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
                    oldInFlight, cause, lateResult>>

Complete ==
    /\ task = "running"
    /\ inFlight
    /\ manager = "up"
    /\ now < deadline
    /\ task' = "done"
    /\ slots' = slots + 1
    /\ inFlight' = FALSE
    /\ UNCHANGED <<now, provider, manager, lastHeartbeat, attempts, deadline,
                    oldInFlight, cause, lateResult>>

Timeout ==
    /\ task = "running"
    /\ inFlight
    /\ now >= deadline
    /\ task' = "lost"
    /\ cause' = "timeout"
    /\ oldInFlight' = TRUE
    /\ inFlight' = FALSE
    /\ UNCHANGED <<now, provider, manager, lastHeartbeat, slots, attempts,
                    deadline, lateResult>>

ExpireManager ==
    /\ manager = "up"
    /\ now - lastHeartbeat >= HEARTBEAT_TIMEOUT
    /\ manager' = "expired"
    /\ task' = IF task = "running" THEN "lost" ELSE task
    /\ cause' = IF task = "running" THEN "manager_lost" ELSE cause
    /\ oldInFlight' = IF task = "running" THEN TRUE ELSE oldInFlight
    /\ inFlight' = IF task = "running" THEN FALSE ELSE inFlight
    /\ UNCHANGED <<now, provider, lastHeartbeat, slots, attempts, deadline,
                    lateResult>>

FailProvider ==
    /\ provider = "active"
    /\ provider' = "failed"
    /\ manager' = "expired"
    /\ task' = IF task = "running" THEN "lost" ELSE task
    /\ cause' = IF task = "running" THEN "provider_lost" ELSE cause
    /\ oldInFlight' = IF task = "running" THEN TRUE ELSE oldInFlight
    /\ inFlight' = IF task = "running" THEN FALSE ELSE inFlight
    /\ slots' = 0
    /\ UNCHANGED <<now, lastHeartbeat, attempts, deadline, lateResult>>

RetryLost ==
    /\ task = "lost"
    /\ attempts < MAX_RETRIES
    /\ provider = "active"
    /\ manager = "up"
    /\ task' = "pending"
    /\ attempts' = attempts + 1
    /\ cause' = "none"
    /\ UNCHANGED <<now, provider, manager, lastHeartbeat, slots, deadline,
                    inFlight, oldInFlight, lateResult>>

LateComplete ==
    /\ oldInFlight
    /\ task \in {"lost", "running", "pending"}
    /\ IF USE_FIXED
          THEN /\ lateResult' = "stale"
               /\ UNCHANGED task
          ELSE /\ task' = "done"
               /\ lateResult' = "accepted"
    /\ oldInFlight' = FALSE
    /\ UNCHANGED <<now, provider, manager, lastHeartbeat, slots, attempts,
                    deadline, inFlight, cause>>

Next ==
    \/ Tick
    \/ Heartbeat
    \/ RequestBlock
    \/ ProvisionBlock
    \/ RegisterManager
    \/ Submit
    \/ Complete
    \/ Timeout
    \/ ExpireManager
    \/ FailProvider
    \/ RetryLost
    \/ LateComplete
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ now \in 0..MAX_TIME
    /\ provider \in ProviderStates
    /\ manager \in ManagerStates
    /\ lastHeartbeat \in 0..MAX_TIME
    /\ slots \in 0..1
    /\ task \in TaskStates
    /\ attempts \in 0..MAX_RETRIES
    /\ deadline \in 0..(MAX_TIME + TASK_TIMEOUT)
    /\ inFlight \in BOOLEAN
    /\ oldInFlight \in BOOLEAN
    /\ cause \in Causes
    /\ lateResult \in LateStates

AdmissionSafety ==
    task = "running" => provider = "active" /\ manager = "up" /\ slots = 0

CapacitySafety ==
    provider # "active" => slots = 0

RetryBoundSafety ==
    attempts <= MAX_RETRIES

TerminalCauseSafety ==
    cause # "none" => task # "done"

StaleResultSafety ==
    lateResult = "accepted" => ~USE_FIXED

=============================================================================
