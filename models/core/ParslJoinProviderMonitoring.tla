----------------------- MODULE ParslJoinProviderMonitoring -----------------------
EXTENDS Naturals, FiniteSets

(***************************************************************************
 * Cross-layer join composition.
 *
 * Logical Futures are separate from physical attempts.  Data staging gates
 * join admission, a provider/manager can lose one running attempt and later
 * provision a replacement, and terminal join state is persisted through a
 * monitoring queue.  A late result from the lost attempt is stale in the
 * fixed branch; the Current branch accepts it and breaks result consistency.
 *************************************************************************** *)

CONSTANT USE_FIXED
TIMEOUT == 1
Tasks == {"a", "b"}
Attempts == 0..1
OuterStates == {"waiting", "joining", "succeeded"}
ManagerStates == {"up", "lost"}
FutureStates == {"pending", "done"}
AttemptStates == {"not_started", "running", "lost", "done"}
MonitorStates == {"none", "queued", "persisted"}

VARIABLES now, outer, dataReady, manager, future, current, age,
          attemptState, acceptedAttempt, staleDelivered, monitor
vars == <<now, outer, dataReady, manager, future, current, age,
           attemptState, acceptedAttempt, staleDelivered, monitor>>

Init ==
    /\ now = 0
    /\ outer = "waiting"
    /\ dataReady = FALSE
    /\ manager = "up"
    /\ future = [t \in Tasks |-> "pending"]
    /\ current = [t \in Tasks |-> 0]
    /\ age = [t \in Tasks |-> 0]
    /\ attemptState = [t \in Tasks, a \in Attempts |-> "not_started"]
    /\ acceptedAttempt = [t \in Tasks |-> 0]
    /\ staleDelivered = [t \in Tasks |-> FALSE]
    /\ monitor = "none"

StageData ==
    /\ ~dataReady
    /\ dataReady' = TRUE
    /\ UNCHANGED <<now, outer, manager, future, current, age,
                    attemptState, acceptedAttempt, staleDelivered, monitor>>

EnterJoin ==
    /\ outer = "waiting"
    /\ dataReady
    /\ outer' = "joining"
    /\ UNCHANGED <<now, dataReady, manager, future, current, age,
                    attemptState, acceptedAttempt, staleDelivered, monitor>>

Start(t) ==
    /\ t \in Tasks
    /\ outer = "joining"
    /\ dataReady
    /\ manager = "up"
    /\ future[t] = "pending"
    /\ attemptState[t, current[t]] = "not_started"
    /\ attemptState' = [attemptState EXCEPT ![t, current[t]] = "running"]
    /\ UNCHANGED <<now, outer, dataReady, manager, future, current, age,
                    acceptedAttempt, staleDelivered, monitor>>

Tick(t) ==
    /\ t \in Tasks
    /\ attemptState[t, current[t]] = "running"
    /\ age[t] < TIMEOUT
    /\ age' = [age EXCEPT ![t] = @ + 1]
    /\ UNCHANGED <<now, outer, dataReady, manager, future, current,
                    attemptState, acceptedAttempt, staleDelivered, monitor>>

Timeout(t) ==
    /\ t \in Tasks
    /\ current[t] = 0
    /\ attemptState[t, 0] = "running"
    /\ age[t] = TIMEOUT
    /\ current' = [current EXCEPT ![t] = 1]
    /\ age' = [age EXCEPT ![t] = 0]
    /\ attemptState' = [attemptState EXCEPT ![t, 0] = "lost"]
    /\ UNCHANGED <<now, outer, dataReady, manager, future,
                    acceptedAttempt, staleDelivered, monitor>>

LoseProvider(t) ==
    /\ t \in Tasks
    /\ manager = "up"
    /\ current[t] = 0
    /\ attemptState[t, 0] = "running"
    /\ \A u \in Tasks: u = t \/ attemptState[u, current[u]] # "running"
    /\ manager' = "lost"
    /\ current' = [current EXCEPT ![t] = 1]
    /\ age' = [age EXCEPT ![t] = 0]
    /\ attemptState' = [attemptState EXCEPT ![t, 0] = "lost"]
    /\ UNCHANGED <<now, outer, dataReady, future,
                    acceptedAttempt, staleDelivered, monitor>>

Provision ==
    /\ manager = "lost"
    /\ manager' = "up"
    /\ UNCHANGED <<now, outer, dataReady, future, current, age,
                    attemptState, acceptedAttempt, staleDelivered, monitor>>

Complete(t, a) ==
    /\ t \in Tasks
    /\ a \in Attempts
    /\ manager = "up"
    /\ attemptState[t, a] = "running"
    /\ attemptState' = [attemptState EXCEPT ![t, a] = "done"]
    /\ future' = [future EXCEPT ![t] = "done"]
    /\ acceptedAttempt' = [acceptedAttempt EXCEPT ![t] = a]
    /\ UNCHANGED <<now, outer, dataReady, manager, current, age,
                    staleDelivered, monitor>>

LateComplete(t, a) ==
    /\ t \in Tasks
    /\ a \in Attempts
    /\ attemptState[t, a] = "lost"
    /\ ~staleDelivered[t]
    /\ staleDelivered' = [staleDelivered EXCEPT ![t] = TRUE]
    /\ IF USE_FIXED
          THEN /\ UNCHANGED <<future, acceptedAttempt>>
          ELSE /\ future' = [future EXCEPT ![t] = "done"]
               /\ acceptedAttempt' = [acceptedAttempt EXCEPT ![t] = a]
    /\ UNCHANGED <<now, outer, dataReady, manager, current, age,
                    attemptState, monitor>>

FinalizeJoin ==
    /\ outer = "joining"
    /\ \A t \in Tasks: future[t] = "done"
    /\ outer' = "succeeded"
    /\ UNCHANGED <<now, dataReady, manager, future, current, age,
                    attemptState, acceptedAttempt, staleDelivered, monitor>>

QueueMonitoring ==
    /\ outer = "succeeded"
    /\ monitor = "none"
    /\ monitor' = "queued"
    /\ UNCHANGED <<now, outer, dataReady, manager, future, current, age,
                    attemptState, acceptedAttempt, staleDelivered>>

PersistMonitoring ==
    /\ monitor = "queued"
    /\ monitor' = "persisted"
    /\ UNCHANGED <<now, outer, dataReady, manager, future, current, age,
                    attemptState, acceptedAttempt, staleDelivered>>

Next ==
    \/ StageData \/ EnterJoin \/ Provision \/ FinalizeJoin
    \/ QueueMonitoring \/ PersistMonitoring
    \/ \E t \in Tasks: Start(t) \/ Tick(t) \/ Timeout(t) \/ LoseProvider(t)
    \/ \E t \in Tasks, a \in Attempts: Complete(t, a) \/ LateComplete(t, a)
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ now \in Nat
    /\ outer \in OuterStates
    /\ dataReady \in BOOLEAN
    /\ manager \in ManagerStates
    /\ future \in [Tasks -> FutureStates]
    /\ current \in [Tasks -> Attempts]
    /\ age \in [Tasks -> 0..TIMEOUT]
    /\ attemptState \in [Tasks \X Attempts -> AttemptStates]
    /\ acceptedAttempt \in [Tasks -> Attempts]
    /\ staleDelivered \in [Tasks -> BOOLEAN]
    /\ monitor \in MonitorStates

ReadinessSafety ==
    \A t \in Tasks: attemptState[t, current[t]] = "running" => dataReady
ProviderSafety ==
    \A t \in Tasks: attemptState[t, current[t]] = "running" => manager = "up"
RetryBoundSafety == \A t \in Tasks: current[t] <= 1
DependencySafety == outer = "succeeded" => \A t \in Tasks: future[t] = "done"
ResultConsistency ==
    \A t \in Tasks:
        future[t] = "done" =>
            /\ acceptedAttempt[t] = current[t]
            /\ attemptState[t, current[t]] = "done"
StaleResultSafety ==
    \A t \in Tasks: staleDelivered[t] =>
        future[t] = "pending" \/ acceptedAttempt[t] = current[t]
MonitoringSafety == monitor = "persisted" => outer = "succeeded"

=============================================================================
