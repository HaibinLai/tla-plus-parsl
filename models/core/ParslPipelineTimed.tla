--------------------------- MODULE ParslPipelineTimed ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Small cross-layer pipeline abstraction.
 *
 * A and B are logical tasks with A -> B.  Each running task has a physical
 * attempt and deadline.  Manager expiry or a task timeout leaves that
 * attempt in flight, so a completion can arrive after the logical task has
 * reached a terminal cause.  The current branch accepts that stale result;
 * the fixed branch records it without changing the terminal state.
 ***************************************************************************)

CONSTANTS MAX_TIME, TASK_TIMEOUT, MAX_RETRIES, USE_FIXED
Tasks == {"A", "B"}
Deps(t) == IF t = "B" THEN {"A"} ELSE {}
TaskStates == {"pending", "running", "succeeded", "failed", "lost"}
Causes == {"none", "timeout", "manager_lost"}
LateStates == {"none", "accepted", "stale"}
EventStates == {"none", "queued", "persisted"}
EventStatuses == {"none", "pending", "running", "succeeded", "lost"}

VARIABLES now, manager, lastHeartbeat, status, attempts, deadline,
          inFlight, cause, result, lateResult, eventState, eventStatus, dbStatus
vars == <<now, manager, lastHeartbeat, status, attempts, deadline,
           inFlight, cause, result, lateResult, eventState, eventStatus, dbStatus>>

Init ==
    /\ MAX_TIME >= 3
    /\ TASK_TIMEOUT > 0
    /\ MAX_RETRIES >= 0
    /\ USE_FIXED \in BOOLEAN
    /\ now = 0
    /\ manager = "up"
    /\ lastHeartbeat = 0
    /\ status = [t \in Tasks |-> "pending"]
    /\ attempts = [t \in Tasks |-> 0]
    /\ deadline = [t \in Tasks |-> 0]
    /\ inFlight = [t \in Tasks |-> FALSE]
    /\ cause = [t \in Tasks |-> "none"]
    /\ result = [t \in Tasks |-> "none"]
    /\ lateResult = [t \in Tasks |-> "none"]
    /\ eventState = [t \in Tasks |-> "none"]
    /\ eventStatus = [t \in Tasks |-> "none"]
    /\ dbStatus = [t \in Tasks |-> "none"]

Tick ==
    /\ now < MAX_TIME
    /\ now' = now + 1
    /\ UNCHANGED <<manager, lastHeartbeat, status, attempts, deadline,
                    inFlight, cause, result, lateResult, eventState,
                    eventStatus, dbStatus>>

Heartbeat ==
    /\ manager = "up"
    /\ lastHeartbeat' = now
    /\ UNCHANGED <<now, manager, status, attempts, deadline, inFlight,
                    cause, result, lateResult, eventState, eventStatus,
                    dbStatus>>

StartTask(t) ==
    /\ t \in Tasks
    /\ status[t] = "pending"
    /\ manager = "up"
    /\ \A d \in Deps(t): status[d] = "succeeded"
    /\ status' = [status EXCEPT ![t] = "running"]
    /\ deadline' = [deadline EXCEPT ![t] = now + TASK_TIMEOUT]
    /\ inFlight' = [inFlight EXCEPT ![t] = TRUE]
    /\ UNCHANGED <<now, manager, lastHeartbeat, attempts, cause, result,
                    lateResult, eventState, eventStatus, dbStatus>>

CompleteTask(t) ==
    /\ t \in Tasks
    /\ status[t] = "running"
    /\ inFlight[t]
    /\ manager = "up"
    /\ now < deadline[t]
    /\ status' = [status EXCEPT ![t] = "succeeded"]
    /\ result' = [result EXCEPT ![t] = "value"]
    /\ inFlight' = [inFlight EXCEPT ![t] = FALSE]
    /\ UNCHANGED <<now, manager, lastHeartbeat, attempts, deadline, cause,
                    lateResult, eventState, eventStatus, dbStatus>>

FailAttempt(t) ==
    /\ t \in Tasks
    /\ status[t] = "running"
    /\ inFlight[t]
    /\ attempts[t] < MAX_RETRIES
    /\ status' = [status EXCEPT ![t] = "pending"]
    /\ attempts' = [attempts EXCEPT ![t] = @ + 1]
    /\ inFlight' = [inFlight EXCEPT ![t] = FALSE]
    /\ UNCHANGED <<now, manager, lastHeartbeat, deadline, cause, result,
                    lateResult, eventState, eventStatus, dbStatus>>

TimeoutTask(t) ==
    /\ t \in Tasks
    /\ status[t] = "running"
    /\ inFlight[t]
    /\ now >= deadline[t]
    /\ status' = [status EXCEPT ![t] = "lost"]
    /\ cause' = [cause EXCEPT ![t] = "timeout"]
    /\ UNCHANGED <<now, manager, lastHeartbeat, attempts, deadline, inFlight,
                    result, lateResult, eventState, eventStatus, dbStatus>>

ExpireManager ==
    /\ manager = "up"
    /\ now - lastHeartbeat >= 2
    /\ manager' = "expired"
    /\ status' = [t \in Tasks |->
                    IF status[t] = "running" THEN "lost" ELSE status[t]]
    /\ cause' = [t \in Tasks |->
                    IF status[t] = "running" THEN "manager_lost" ELSE cause[t]]
    /\ UNCHANGED <<now, lastHeartbeat, attempts, deadline, inFlight, result,
                    lateResult, eventState, eventStatus, dbStatus>>

RecoverManager ==
    /\ manager = "expired"
    /\ manager' = "up"
    /\ lastHeartbeat' = now
    /\ UNCHANGED <<now, status, attempts, deadline, inFlight, cause, result,
                    lateResult, eventState, eventStatus, dbStatus>>

RetryLost(t) ==
    /\ t \in Tasks
    /\ status[t] = "lost"
    /\ attempts[t] < MAX_RETRIES
    /\ status' = [status EXCEPT ![t] = "pending"]
    /\ attempts' = [attempts EXCEPT ![t] = @ + 1]
    /\ cause' = [cause EXCEPT ![t] = "none"]
    /\ UNCHANGED <<now, manager, lastHeartbeat, deadline, inFlight, result,
                    lateResult, eventState, eventStatus, dbStatus>>

LateComplete(t) ==
    /\ t \in Tasks
    /\ status[t] = "lost"
    /\ inFlight[t]
    /\ IF USE_FIXED
          THEN /\ lateResult' = [lateResult EXCEPT ![t] = "stale"]
               /\ UNCHANGED status
          ELSE /\ status' = [status EXCEPT ![t] = "succeeded"]
               /\ lateResult' = [lateResult EXCEPT ![t] = "accepted"]
    /\ inFlight' = [inFlight EXCEPT ![t] = FALSE]
    /\ result' = [result EXCEPT ![t] = "value"]
    /\ UNCHANGED <<now, manager, lastHeartbeat, attempts, deadline, cause,
                    eventState, eventStatus, dbStatus>>

EmitStatus(t) ==
    /\ t \in Tasks
    /\ status[t] \in {"succeeded", "lost"}
    /\ eventState[t] = "none"
    /\ eventState' = [eventState EXCEPT ![t] = "queued"]
    /\ eventStatus' = [eventStatus EXCEPT ![t] = status[t]]
    /\ UNCHANGED <<now, manager, lastHeartbeat, status, attempts, deadline,
                    inFlight, cause, result, lateResult, dbStatus>>

PersistStatus(t) ==
    /\ t \in Tasks
    /\ eventState[t] = "queued"
    /\ eventState' = [eventState EXCEPT ![t] = "persisted"]
    /\ dbStatus' = [dbStatus EXCEPT ![t] = eventStatus[t]]
    /\ UNCHANGED <<now, manager, lastHeartbeat, status, attempts, deadline,
                    inFlight, cause, result, lateResult, eventStatus>>

Next ==
    \/ Tick
    \/ Heartbeat
    \/ ExpireManager
    \/ RecoverManager
    \/ \E t \in Tasks: StartTask(t)
    \/ \E t \in Tasks: CompleteTask(t)
    \/ \E t \in Tasks: FailAttempt(t)
    \/ \E t \in Tasks: TimeoutTask(t)
    \/ \E t \in Tasks: RetryLost(t)
    \/ \E t \in Tasks: LateComplete(t)
    \/ \E t \in Tasks: EmitStatus(t)
    \/ \E t \in Tasks: PersistStatus(t)
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ now \in 0..MAX_TIME
    /\ manager \in {"up", "expired"}
    /\ lastHeartbeat \in 0..MAX_TIME
    /\ status \in [Tasks -> TaskStates]
    /\ attempts \in [Tasks -> 0..MAX_RETRIES]
    /\ deadline \in [Tasks -> 0..(MAX_TIME + TASK_TIMEOUT)]
    /\ inFlight \in [Tasks -> BOOLEAN]
    /\ cause \in [Tasks -> Causes]
    /\ result \in [Tasks -> {"none", "value"}]
    /\ lateResult \in [Tasks -> LateStates]
    /\ eventState \in [Tasks -> EventStates]
    /\ eventStatus \in [Tasks -> EventStatuses]
    /\ dbStatus \in [Tasks -> EventStatuses]

DependencySafety ==
    /\ status["B"] \in {"running", "succeeded"} => status["A"] = "succeeded"

RetryBoundSafety ==
    \A t \in Tasks: attempts[t] <= MAX_RETRIES

ResultConsistency ==
    \A t \in Tasks: status[t] = "succeeded" => result[t] = "value"

TerminalCauseSafety ==
    \A t \in Tasks: cause[t] \in {"timeout", "manager_lost"} =>
        status[t] # "succeeded"

StaleResultSafety ==
    \A t \in Tasks: lateResult[t] = "accepted" => ~USE_FIXED

DatabaseConsistency ==
    \A t \in Tasks: dbStatus[t] = "succeeded" => status[t] = "succeeded"

DatabaseTerminalCauseSafety ==
    \A t \in Tasks: cause[t] \in {"timeout", "manager_lost"} =>
        dbStatus[t] # "succeeded"

=============================================================================
