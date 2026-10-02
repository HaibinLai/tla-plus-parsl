------------------------ MODULE ParslHeartbeatProviderBoundary ------------------------
EXTENDS Naturals, Integers

(***************************************************************************
 * A small cross-layer boundary model for HTEX manager liveness and provider
 * capacity.  `Interchange.expire_bad_managers` uses a strict `>` comparison;
 * an expired manager releases its physical slot, the logical task enters a
 * retry generation, and the old attempt may still deliver a result later.
 *
 * The Current branch accepts that stale result as the retry's result.  The
 * Fixed branch keeps logical task state tied to the current attempt generation.
 ***************************************************************************)

CONSTANTS HEARTBEAT_THRESHOLD, MAX_TIME, MAX_RETRIES, USE_FIXED

ProviderStates == {"active", "failed"}
ManagerStates == {"up", "expired"}
TaskStates == {"pending", "running", "retry_wait", "succeeded", "failed"}
ResultSources == {"none", "current", "old"}

VARIABLES now, lastHeartbeat, provider, manager, slots, task, attempt,
          deadline, oldInFlight, future, resultSource

vars == <<now, lastHeartbeat, provider, manager, slots, task, attempt,
          deadline, oldInFlight, future, resultSource>>

Init ==
    /\ HEARTBEAT_THRESHOLD > 0
    /\ MAX_TIME > HEARTBEAT_THRESHOLD
    /\ MAX_RETRIES >= 1
    /\ USE_FIXED \in BOOLEAN
    /\ now = 0
    /\ lastHeartbeat = 0
    /\ provider = "active"
    /\ manager = "up"
    /\ slots = 1
    /\ task = "pending"
    /\ attempt = 0
    /\ deadline = -1
    /\ oldInFlight = FALSE
    /\ future = "unresolved"
    /\ resultSource = "none"

Tick ==
    /\ now < MAX_TIME
    /\ now' = now + 1
    /\ UNCHANGED <<lastHeartbeat, provider, manager, slots, task, attempt,
                    deadline, oldInFlight, future, resultSource>>

Heartbeat ==
    /\ manager = "up"
    /\ lastHeartbeat' = now
    /\ UNCHANGED <<now, provider, manager, slots, task, attempt, deadline,
                    oldInFlight, future, resultSource>>

Submit ==
    /\ provider = "active"
    /\ manager = "up"
    /\ slots = 1
    /\ task = "pending"
    /\ slots' = 0
    /\ task' = "running"
    /\ deadline' = now + 2
    /\ UNCHANGED <<now, lastHeartbeat, provider, manager, attempt,
                    oldInFlight, future, resultSource>>

CompleteCurrent ==
    /\ task = "running"
    /\ manager = "up"
    /\ now < deadline
    /\ task' = "succeeded"
    /\ slots' = 1
    /\ future' = "resolved"
    /\ resultSource' = "current"
    /\ UNCHANGED <<now, lastHeartbeat, provider, manager, attempt, deadline,
                    oldInFlight>>

ExpireManager ==
    /\ manager = "up"
    /\ now - lastHeartbeat > HEARTBEAT_THRESHOLD
    /\ manager' = "expired"
    /\ task' = IF task = "running" THEN "retry_wait" ELSE task
    /\ oldInFlight' = IF task = "running" THEN TRUE ELSE oldInFlight
    /\ slots' = 0
    /\ UNCHANGED <<now, lastHeartbeat, provider, attempt, deadline, future,
                    resultSource>>

FailProvider ==
    /\ provider = "active"
    /\ provider' = "failed"
    /\ manager' = "expired"
    /\ task' = IF task = "running" THEN "retry_wait" ELSE task
    /\ oldInFlight' = IF task = "running" THEN TRUE ELSE oldInFlight
    /\ slots' = 0
    /\ UNCHANGED <<now, lastHeartbeat, attempt, deadline, future,
                    resultSource>>

RegisterManager ==
    /\ provider = "active"
    /\ manager = "expired"
    /\ manager' = "up"
    /\ slots' = 1
    /\ lastHeartbeat' = now
    /\ UNCHANGED <<now, provider, task, attempt, deadline, oldInFlight,
                    future, resultSource>>

Retry ==
    /\ task = "retry_wait"
    /\ attempt < MAX_RETRIES
    /\ provider = "active"
    /\ manager = "up"
    /\ task' = "pending"
    /\ attempt' = attempt + 1
    /\ UNCHANGED <<now, lastHeartbeat, provider, manager, slots, deadline,
                    oldInFlight, future, resultSource>>

DeliverOldResult ==
    /\ oldInFlight
    /\ IF USE_FIXED
          THEN /\ oldInFlight' = FALSE
               /\ resultSource' = "old"
               /\ UNCHANGED <<now, lastHeartbeat, provider, manager, slots,
                               task, attempt, deadline, future>>
          ELSE /\ oldInFlight' = FALSE
               /\ task' = "succeeded"
               /\ future' = "resolved"
               /\ resultSource' = "old"
               /\ UNCHANGED <<now, lastHeartbeat, provider, manager, slots,
                               attempt, deadline>>

Next ==
    \/ Tick
    \/ Heartbeat
    \/ Submit
    \/ CompleteCurrent
    \/ ExpireManager
    \/ FailProvider
    \/ RegisterManager
    \/ Retry
    \/ DeliverOldResult
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ now \in 0..MAX_TIME
    /\ lastHeartbeat \in 0..MAX_TIME
    /\ provider \in ProviderStates
    /\ manager \in ManagerStates
    /\ slots \in 0..1
    /\ task \in TaskStates
    /\ attempt \in 0..MAX_RETRIES
    /\ deadline \in -1..(MAX_TIME + 2)
    /\ oldInFlight \in BOOLEAN
    /\ future \in {"unresolved", "resolved"}
    /\ resultSource \in ResultSources

StrictExpirySafety ==
    manager = "expired" /\ provider = "active" =>
        now - lastHeartbeat > HEARTBEAT_THRESHOLD

AdmissionSafety ==
    task = "running" => provider = "active" /\ manager = "up" /\ slots = 0

RetryBoundSafety == attempt <= MAX_RETRIES

StaleResultSafety ==
    resultSource = "old" => USE_FIXED

TerminalSourceSafety ==
    future = "resolved" => task = "succeeded"

=============================================================================
CONSTANTS
    HEARTBEAT_THRESHOLD = 2
    MAX_TIME = 5
    MAX_RETRIES = 1
    USE_FIXED = TRUE

SPECIFICATION Spec

INVARIANTS
    TypeOK
    StrictExpirySafety
    AdmissionSafety
    RetryBoundSafety
    StaleResultSafety
    TerminalSourceSafety
