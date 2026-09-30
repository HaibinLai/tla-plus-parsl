--------------------------- MODULE ParslThreeConcurrentTimeouts ---------------------------
EXTENDS Naturals, Integers

(***************************************************************************
 * Three independent task timers.
 *
 * Each logical task has its own deadline and retry generation.  A late result
 * names its originating task and generation; the fixed branch accepts it only
 * when both still identify the current attempt.
 ***************************************************************************)

CONSTANT USE_FIXED

Tasks == {"A", "B", "C"}
TaskStates == {"pending", "running", "timed_out", "succeeded"}
ResultStates == {"none", "sent", "accepted", "stale"}

Limit(t) == CASE t = "A" -> 1 [] t = "B" -> 2 [] OTHER -> 3

VARIABLES now, task, attempt, deadline, result, resultAttempt

vars == <<now, task, attempt, deadline, result, resultAttempt>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ now = 0
    /\ task = [t \in Tasks |-> "pending"]
    /\ attempt = [t \in Tasks |-> 0]
    /\ deadline = [t \in Tasks |-> -1]
    /\ result = [t \in Tasks |-> "none"]
    /\ resultAttempt = [t \in Tasks |-> -1]

Tick ==
    /\ now < 5
    /\ \A t \in Tasks : task[t] = "running" => now < deadline[t]
    /\ now' = now + 1
    /\ UNCHANGED <<task, attempt, deadline, result, resultAttempt>>

Start(t) ==
    /\ t \in Tasks
    /\ task[t] = "pending"
    /\ task' = [task EXCEPT ![t] = "running"]
    /\ deadline' = [deadline EXCEPT ![t] = now + Limit(t)]
    /\ UNCHANGED <<now, attempt, result, resultAttempt>>

Timeout(t) ==
    /\ t \in Tasks
    /\ task[t] = "running"
    /\ now >= deadline[t]
    /\ task' = [task EXCEPT ![t] = "timed_out"]
    /\ UNCHANGED <<now, attempt, deadline, result, resultAttempt>>

Retry(t) ==
    /\ t \in Tasks
    /\ task[t] = "timed_out"
    /\ attempt[t] = 0
    /\ task' = [task EXCEPT ![t] = "pending"]
    /\ attempt' = [attempt EXCEPT ![t] = 1]
    /\ result' = [result EXCEPT ![t] = "none"]
    /\ resultAttempt' = [resultAttempt EXCEPT ![t] = -1]
    /\ UNCHANGED <<now, deadline>>

Complete(t) ==
    /\ t \in Tasks
    /\ task[t] = "running"
    /\ now < deadline[t]
    /\ task' = [task EXCEPT ![t] = "succeeded"]
    /\ UNCHANGED <<now, attempt, deadline, result, resultAttempt>>

SendLate(t) ==
    /\ t \in Tasks
    /\ task[t] = "timed_out"
    /\ result[t] = "none"
    /\ result' = [result EXCEPT ![t] = "sent"]
    /\ resultAttempt' = [resultAttempt EXCEPT ![t] = attempt[t]
                         - 1]
    /\ UNCHANGED <<now, task, attempt, deadline>>

DeliverLate(t) ==
    /\ t \in Tasks
    /\ result[t] = "sent"
    /\ result' = [result EXCEPT ![t] =
          IF USE_FIXED THEN "stale" ELSE "accepted"]
    /\ task' = [task EXCEPT ![t] =
          IF USE_FIXED THEN @ ELSE "succeeded"]
    /\ UNCHANGED <<now, attempt, deadline, resultAttempt>>

Next ==
    \/ Tick
    \/ \E t \in Tasks : Start(t) \/ Timeout(t) \/ Retry(t) \/ Complete(t)
                            \/ SendLate(t) \/ DeliverLate(t)
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ now \in 0..5
    /\ task \in [Tasks -> TaskStates]
    /\ attempt \in [Tasks -> 0..1]
    /\ deadline \in [Tasks -> (-1)..8]
    /\ result \in [Tasks -> ResultStates]
    /\ resultAttempt \in [Tasks -> (-1)..1]

IndependentTimers ==
    \A t \in Tasks : task[t] = "running" => now <= deadline[t]

RetryBound == \A t \in Tasks : attempt[t] <= 1

NoAcceptedLateResult ==
    \A t \in Tasks : result[t] # "accepted"

TerminalStability ==
    \A t \in Tasks : task[t] = "succeeded" => result[t] # "accepted"

=============================================================================
