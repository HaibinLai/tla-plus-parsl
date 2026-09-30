---------------------- MODULE ParslJoinRetryStaleResult ----------------------
EXTENDS Naturals, FiniteSets

(***************************************************************************
 * Cross-layer join model.
 *
 * Two logical inner Futures feed one outer join.  Each logical task has a
 * bounded physical attempt.  A timeout loses attempt 0 and starts attempt 1;
 * the old attempt may still report a late result.  The fixed branch accepts
 * only the current attempt for the logical Future.  This keeps join
 * completion, retry correlation, and result consistency in one small model.
 *************************************************************************** *)

CONSTANT USE_FIXED
TIMEOUT == 1
Tasks == {"a", "b"}
Attempts == 0..1
FutureStates == {"pending", "done"}
AttemptStates == {"not_started", "running", "lost", "done"}
OuterStates == {"joining", "succeeded"}

VARIABLES now, outer, future, current, age, attemptState,
          acceptedAttempt, staleDelivered
vars == <<now, outer, future, current, age, attemptState,
           acceptedAttempt, staleDelivered>>

Init ==
    /\ now = 0
    /\ outer = "joining"
    /\ future = [t \in Tasks |-> "pending"]
    /\ current = [t \in Tasks |-> 0]
    /\ age = [t \in Tasks |-> 0]
    /\ attemptState = [t \in Tasks, a \in Attempts |-> "not_started"]
    /\ acceptedAttempt = [t \in Tasks |-> 0]
    /\ staleDelivered = [t \in Tasks |-> FALSE]

Start(t) ==
    /\ t \in Tasks
    /\ future[t] = "pending"
    /\ attemptState[t, current[t]] = "not_started"
    /\ attemptState' = [attemptState EXCEPT ![t, current[t]] = "running"]
    /\ UNCHANGED <<now, outer, future, current, age, acceptedAttempt,
                    staleDelivered>>

Tick(t) ==
    /\ t \in Tasks
    /\ attemptState[t, current[t]] = "running"
    /\ age[t] < TIMEOUT
    /\ age' = [age EXCEPT ![t] = @ + 1]
    /\ UNCHANGED <<now, outer, future, current, attemptState,
                    acceptedAttempt, staleDelivered>>

Timeout(t) ==
    /\ t \in Tasks
    /\ current[t] = 0
    /\ attemptState[t, current[t]] = "running"
    /\ age[t] = TIMEOUT
    /\ current' = [current EXCEPT ![t] = 1]
    /\ age' = [age EXCEPT ![t] = 0]
    /\ attemptState' = [attemptState EXCEPT
                           ![t, 0] = "lost",
                           ![t, 1] = "running"]
    /\ UNCHANGED <<now, outer, future, acceptedAttempt, staleDelivered>>

Complete(t, a) ==
    /\ t \in Tasks
    /\ a \in Attempts
    /\ attemptState[t, a] = "running"
    /\ attemptState' = [attemptState EXCEPT ![t, a] = "done"]
    /\ future' = [future EXCEPT ![t] = "done"]
    /\ acceptedAttempt' = [acceptedAttempt EXCEPT ![t] = a]
    /\ UNCHANGED <<now, outer, current, age, staleDelivered>>

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
    /\ UNCHANGED <<now, outer, current, age, attemptState>>

Finalize ==
    /\ outer = "joining"
    /\ \A t \in Tasks: future[t] = "done"
    /\ outer' = "succeeded"
    /\ UNCHANGED <<now, future, current, age, attemptState,
                    acceptedAttempt, staleDelivered>>

Next ==
    \/ \E t \in Tasks: Start(t) \/ Tick(t) \/ Timeout(t)
    \/ \E t \in Tasks, a \in Attempts: Complete(t, a) \/ LateComplete(t, a)
    \/ Finalize
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ now \in Nat
    /\ outer \in OuterStates
    /\ future \in [Tasks -> FutureStates]
    /\ current \in [Tasks -> Attempts]
    /\ age \in [Tasks -> 0..TIMEOUT]
    /\ attemptState \in [Tasks \X Attempts -> AttemptStates]
    /\ acceptedAttempt \in [Tasks -> Attempts]
    /\ staleDelivered \in [Tasks -> BOOLEAN]

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

=============================================================================
