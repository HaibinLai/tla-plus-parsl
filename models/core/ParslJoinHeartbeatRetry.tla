------------------------- MODULE ParslJoinHeartbeatRetry -------------------------
EXTENDS Naturals, FiniteSets

(***************************************************************************
 * Join retry under heartbeat and task deadlines.
 *
 * Logical time advances independently of heartbeat delivery.  A manager can
 * expire while one physical attempt is running; provisioning restores the
 * manager and starts a bounded retry.  A late completion from the expired
 * attempt must not resolve the logical Future in the fixed branch.
 *************************************************************************** *)

CONSTANT USE_FIXED
MAX_TIME == 4
HEARTBEAT_TIMEOUT == 2
TASK_TIMEOUT == 1
Tasks == {"a", "b"}
Attempts == 0..1
ManagerStates == {"up", "expired"}
OuterStates == {"joining", "succeeded"}
FutureStates == {"pending", "done"}
PhysicalStates == {"not_started", "running", "lost", "done"}

VARIABLES now, manager, lastHeartbeat, outer, future, current, age,
          physical, acceptedAttempt, staleSeen
vars == <<now, manager, lastHeartbeat, outer, future, current, age,
           physical, acceptedAttempt, staleSeen>>

Init ==
    /\ now = 0
    /\ manager = "up"
    /\ lastHeartbeat = 0
    /\ outer = "joining"
    /\ future = [t \in Tasks |-> "pending"]
    /\ current = [t \in Tasks |-> 0]
    /\ age = [t \in Tasks |-> 0]
    /\ physical = [t \in Tasks, a \in Attempts |-> "not_started"]
    /\ acceptedAttempt = [t \in Tasks |-> 0]
    /\ staleSeen = [t \in Tasks |-> FALSE]

Tick ==
    /\ now < MAX_TIME
    /\ now' = now + 1
    /\ UNCHANGED <<manager, lastHeartbeat, outer, future, current, age,
                    physical, acceptedAttempt, staleSeen>>

Heartbeat ==
    /\ manager = "up"
    /\ lastHeartbeat' = now
    /\ UNCHANGED <<now, manager, outer, future, current, age,
                    physical, acceptedAttempt, staleSeen>>

Start(t) ==
    /\ t \in Tasks
    /\ manager = "up"
    /\ future[t] = "pending"
    /\ physical[t, current[t]] = "not_started"
    /\ physical' = [physical EXCEPT ![t, current[t]] = "running"]
    /\ UNCHANGED <<now, manager, lastHeartbeat, outer, future, current,
                    age, acceptedAttempt, staleSeen>>

TickTask(t) ==
    /\ t \in Tasks
    /\ physical[t, current[t]] = "running"
    /\ age[t] < TASK_TIMEOUT
    /\ age' = [age EXCEPT ![t] = @ + 1]
    /\ UNCHANGED <<now, manager, lastHeartbeat, outer, future, current,
                    physical, acceptedAttempt, staleSeen>>

TimeoutTask(t) ==
    /\ t \in Tasks
    /\ manager = "up"
    /\ future[t] = "pending"
    /\ current[t] = 0
    /\ physical[t, 0] = "running"
    /\ age[t] = TASK_TIMEOUT
    /\ current' = [current EXCEPT ![t] = 1]
    /\ age' = [age EXCEPT ![t] = 0]
    /\ physical' = [physical EXCEPT ![t, 0] = "lost"]
    /\ UNCHANGED <<now, manager, lastHeartbeat, outer, future,
                    acceptedAttempt, staleSeen>>

ExpireRunningManager(t) ==
    /\ t \in Tasks
    /\ manager = "up"
    /\ now - lastHeartbeat >= HEARTBEAT_TIMEOUT
    /\ current[t] = 0
    /\ physical[t, current[t]] = "running"
    /\ \A u \in Tasks: u = t \/ physical[u, current[u]] # "running"
    /\ manager' = "expired"
    /\ current' = [current EXCEPT ![t] = 1]
    /\ age' = [age EXCEPT ![t] = 0]
    /\ physical' = [physical EXCEPT ![t, 0] = "lost"]
    /\ UNCHANGED <<now, lastHeartbeat, outer, future,
                    acceptedAttempt, staleSeen>>

ExpireIdleManager ==
    /\ manager = "up"
    /\ now - lastHeartbeat >= HEARTBEAT_TIMEOUT
    /\ \A t \in Tasks: physical[t, current[t]] # "running"
    /\ manager' = "expired"
    /\ UNCHANGED <<now, lastHeartbeat, outer, future, current, age,
                    physical, acceptedAttempt, staleSeen>>

Provision ==
    /\ manager = "expired"
    /\ manager' = "up"
    /\ UNCHANGED <<now, lastHeartbeat, outer, future, current, age,
                    physical, acceptedAttempt, staleSeen>>

Complete(t) ==
    /\ t \in Tasks
    /\ manager = "up"
    /\ physical[t, current[t]] = "running"
    /\ physical' = [physical EXCEPT ![t, current[t]] = "done"]
    /\ future' = [future EXCEPT ![t] = "done"]
    /\ acceptedAttempt' = [acceptedAttempt EXCEPT ![t] = current[t]]
    /\ UNCHANGED <<now, manager, lastHeartbeat, outer, current, age,
                    staleSeen>>

LateComplete(t) ==
    /\ t \in Tasks
    /\ physical[t, 0] = "lost"
    /\ ~staleSeen[t]
    /\ staleSeen' = [staleSeen EXCEPT ![t] = TRUE]
    /\ IF USE_FIXED
          THEN /\ UNCHANGED <<future, acceptedAttempt>>
          ELSE /\ future' = [future EXCEPT ![t] = "done"]
               /\ acceptedAttempt' = [acceptedAttempt EXCEPT ![t] = 0]
    /\ UNCHANGED <<now, manager, lastHeartbeat, outer, current, age, physical>>

Finalize ==
    /\ outer = "joining"
    /\ \A t \in Tasks: future[t] = "done"
    /\ outer' = "succeeded"
    /\ UNCHANGED <<now, manager, lastHeartbeat, future, current, age,
                    physical, acceptedAttempt, staleSeen>>

Next ==
    \/ Tick \/ Heartbeat \/ Provision \/ ExpireIdleManager \/ Finalize
    \/ \E t \in Tasks: Start(t) \/ TickTask(t) \/ TimeoutTask(t)
                         \/ ExpireRunningManager(t) \/ Complete(t)
                         \/ LateComplete(t)
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ now \in 0..MAX_TIME
    /\ manager \in ManagerStates
    /\ lastHeartbeat \in 0..MAX_TIME
    /\ outer \in OuterStates
    /\ future \in [Tasks -> FutureStates]
    /\ current \in [Tasks -> Attempts]
    /\ age \in [Tasks -> 0..TASK_TIMEOUT]
    /\ physical \in [Tasks \X Attempts -> PhysicalStates]
    /\ acceptedAttempt \in [Tasks -> Attempts]
    /\ staleSeen \in [Tasks -> BOOLEAN]

HeartbeatSafety == manager = "expired" => now - lastHeartbeat >= HEARTBEAT_TIMEOUT
RunningManagerSafety ==
    \A t \in Tasks: physical[t, current[t]] = "running" => manager = "up"
RetryBoundSafety == \A t \in Tasks: current[t] <= 1
DependencySafety == outer = "succeeded" => \A t \in Tasks: future[t] = "done"
ResultConsistency ==
    \A t \in Tasks:
        future[t] = "done" => acceptedAttempt[t] = current[t]
StaleResultSafety ==
    \A t \in Tasks: staleSeen[t] =>
        future[t] = "pending" \/ acceptedAttempt[t] = current[t]

=============================================================================
