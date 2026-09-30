--------------------------- MODULE ParslJoinZMQRetry ---------------------------
EXTENDS Naturals, FiniteSets

(***************************************************************************
 * Cross-layer join, retry, and ZMQ serialization.
 *
 * Two logical join dependencies use physical attempts.  Each attempt has a
 * task envelope and a result envelope, and every envelope is correlated by
 * (logical task, attempt).  Timeout may lose a worker while its result frame
 * is still in flight.  The fixed branch rejects that stale result; the
 * Current branch resolves the logical Future from it.
 *************************************************************************** *)

CONSTANT USE_FIXED
TIMEOUT == 1
Tasks == {"a", "b"}
Attempts == 0..1
OuterStates == {"joining", "succeeded"}
FutureStates == {"pending", "done"}
PhysicalStates == {"not_started", "running", "lost"}
WireStates == {"none", "task_framed", "task_sent", "task_received",
               "task_decoded", "result_framed", "result_sent",
               "result_received", "result_decoded", "resolved", "stale",
               "rejected"}

VARIABLES now, outer, future, current, age, physical, wire, frameValid,
          objectVersion, capturedVersion, dispatchVersion,
          acceptedAttempt, staleSeen
vars == <<now, outer, future, current, age, physical, wire, frameValid,
           objectVersion, capturedVersion, dispatchVersion,
           acceptedAttempt, staleSeen>>

Init ==
    /\ now = 0
    /\ outer = "joining"
    /\ future = [t \in Tasks |-> "pending"]
    /\ current = [t \in Tasks |-> 0]
    /\ age = [t \in Tasks |-> 0]
    /\ physical = [t \in Tasks, a \in Attempts |-> "not_started"]
    /\ wire = [t \in Tasks, a \in Attempts |-> "none"]
    /\ frameValid = [t \in Tasks, a \in Attempts |-> TRUE]
    /\ objectVersion = 0
    /\ capturedVersion = [t \in Tasks, a \in Attempts |-> 0]
    /\ dispatchVersion = [t \in Tasks, a \in Attempts |-> 0]
    /\ acceptedAttempt = [t \in Tasks |-> 0]
    /\ staleSeen = [t \in Tasks |-> FALSE]

StartAttempt(t) ==
    /\ t \in Tasks
    /\ physical[t, current[t]] = "not_started"
    /\ wire[t, current[t]] = "none"
    /\ wire' = [wire EXCEPT ![t, current[t]] = "task_framed"]
    /\ capturedVersion' = [capturedVersion EXCEPT
                              ![t, current[t]] = objectVersion]
    /\ UNCHANGED <<now, outer, future, current, age, physical,
                    frameValid, objectVersion, dispatchVersion,
                    acceptedAttempt, staleSeen>>

SendTask(t) ==
    /\ t \in Tasks
    /\ wire[t, current[t]] = "task_framed"
    /\ frameValid[t, current[t]]
    /\ wire' = [wire EXCEPT ![t, current[t]] = "task_sent"]
    /\ UNCHANGED <<now, outer, future, current, age, physical,
                    frameValid, objectVersion, capturedVersion,
                    dispatchVersion, acceptedAttempt, staleSeen>>

ReceiveTask(t) ==
    /\ t \in Tasks
    /\ wire[t, current[t]] = "task_sent"
    /\ wire' = [wire EXCEPT ![t, current[t]] = "task_received"]
    /\ UNCHANGED <<now, outer, future, current, age, physical,
                    frameValid, objectVersion, capturedVersion,
                    dispatchVersion, acceptedAttempt, staleSeen>>

DecodeTask(t) ==
    /\ t \in Tasks
    /\ wire[t, current[t]] = "task_received"
    /\ frameValid[t, current[t]]
    /\ wire' = [wire EXCEPT ![t, current[t]] = "task_decoded"]
    /\ UNCHANGED <<now, outer, future, current, age, physical,
                    frameValid, objectVersion, capturedVersion,
                    dispatchVersion, acceptedAttempt, staleSeen>>

DispatchTask(t) ==
    /\ t \in Tasks
    /\ wire[t, current[t]] = "task_decoded"
    /\ physical' = [physical EXCEPT ![t, current[t]] = "running"]
    /\ dispatchVersion' = [dispatchVersion EXCEPT ![t, current[t]] =
          IF USE_FIXED THEN capturedVersion[t, current[t]] ELSE objectVersion]
    /\ UNCHANGED <<now, outer, future, current, age, wire,
                    frameValid, objectVersion, capturedVersion,
                    acceptedAttempt, staleSeen>>

MutateObject ==
    /\ objectVersion' = 1 - objectVersion
    /\ UNCHANGED <<now, outer, future, current, age, physical, wire,
                    frameValid, capturedVersion, dispatchVersion,
                    acceptedAttempt, staleSeen>>

Tick(t) ==
    /\ t \in Tasks
    /\ physical[t, current[t]] = "running"
    /\ age[t] < TIMEOUT
    /\ age' = [age EXCEPT ![t] = @ + 1]
    /\ UNCHANGED <<now, outer, future, current, physical, wire,
                    frameValid, objectVersion, capturedVersion,
                    dispatchVersion, acceptedAttempt, staleSeen>>

Timeout(t) ==
    /\ t \in Tasks
    /\ future[t] = "pending"
    /\ current[t] = 0
    /\ physical[t, 0] = "running"
    /\ age[t] = TIMEOUT
    /\ current' = [current EXCEPT ![t] = 1]
    /\ age' = [age EXCEPT ![t] = 0]
    /\ physical' = [physical EXCEPT ![t, 0] = "lost"]
    /\ UNCHANGED <<now, outer, future, wire, frameValid,
                    objectVersion, capturedVersion, dispatchVersion,
                    acceptedAttempt, staleSeen>>

Complete(t) ==
    /\ t \in Tasks
    /\ physical[t, current[t]] = "running"
    /\ wire[t, current[t]] = "task_decoded"
    /\ wire' = [wire EXCEPT ![t, current[t]] = "result_framed"]
    /\ UNCHANGED <<now, outer, future, current, age, physical,
                    frameValid, objectVersion, capturedVersion,
                    dispatchVersion, acceptedAttempt, staleSeen>>

LateComplete(t) ==
    /\ t \in Tasks
    /\ physical[t, 0] = "lost"
    /\ wire[t, 0] = "task_decoded"
    /\ wire' = [wire EXCEPT ![t, 0] = "result_framed"]
    /\ UNCHANGED <<now, outer, future, current, age, physical,
                    frameValid, objectVersion, capturedVersion,
                    dispatchVersion, acceptedAttempt, staleSeen>>

SendResult(t, a) ==
    /\ t \in Tasks
    /\ a \in Attempts
    /\ wire[t, a] = "result_framed"
    /\ frameValid[t, a]
    /\ wire' = [wire EXCEPT ![t, a] = "result_sent"]
    /\ UNCHANGED <<now, outer, future, current, age, physical,
                    frameValid, objectVersion, capturedVersion,
                    dispatchVersion, acceptedAttempt, staleSeen>>

ReceiveResult(t, a) ==
    /\ t \in Tasks
    /\ a \in Attempts
    /\ wire[t, a] = "result_sent"
    /\ wire' = [wire EXCEPT ![t, a] = "result_received"]
    /\ UNCHANGED <<now, outer, future, current, age, physical,
                    frameValid, objectVersion, capturedVersion,
                    dispatchVersion, acceptedAttempt, staleSeen>>

DecodeResult(t, a) ==
    /\ t \in Tasks
    /\ a \in Attempts
    /\ wire[t, a] = "result_received"
    /\ frameValid[t, a]
    /\ wire' = [wire EXCEPT ![t, a] = "result_decoded"]
    /\ UNCHANGED <<now, outer, future, current, age, physical,
                    frameValid, objectVersion, capturedVersion,
                    dispatchVersion, acceptedAttempt, staleSeen>>

ResolveResult(t, a) ==
    /\ t \in Tasks
    /\ a \in Attempts
    /\ wire[t, a] = "result_decoded"
    /\ IF a = current[t]
          THEN /\ wire' = [wire EXCEPT ![t, a] = "resolved"]
               /\ future' = [future EXCEPT ![t] = "done"]
               /\ acceptedAttempt' = [acceptedAttempt EXCEPT ![t] = a]
               /\ UNCHANGED staleSeen
          ELSE /\ staleSeen' = [staleSeen EXCEPT ![t] = TRUE]
               /\ IF USE_FIXED
                     THEN /\ wire' = [wire EXCEPT ![t, a] = "stale"]
                          /\ UNCHANGED <<future, acceptedAttempt>>
                     ELSE /\ wire' = [wire EXCEPT ![t, a] = "resolved"]
                          /\ future' = [future EXCEPT ![t] = "done"]
                          /\ acceptedAttempt' = [acceptedAttempt EXCEPT ![t] = a]
    /\ UNCHANGED <<now, outer, current, age, physical, frameValid,
                    objectVersion, capturedVersion, dispatchVersion>>

RejectCorrupt(t, a) ==
    /\ t \in Tasks
    /\ a \in Attempts
    /\ wire[t, a] \in {"task_framed", "result_framed"}
    /\ ~frameValid[t, a]
    /\ wire' = [wire EXCEPT ![t, a] = "rejected"]
    /\ UNCHANGED <<now, outer, future, current, age, physical,
                    frameValid, objectVersion, capturedVersion,
                    dispatchVersion, acceptedAttempt, staleSeen>>

CorruptFrame(t, a) ==
    /\ t \in Tasks
    /\ a \in Attempts
    /\ wire[t, a] \in {"task_framed", "result_framed"}
    /\ frameValid[t, a]
    /\ frameValid' = [frameValid EXCEPT ![t, a] = FALSE]
    /\ UNCHANGED <<now, outer, future, current, age, physical,
                    wire, objectVersion, capturedVersion, dispatchVersion,
                    acceptedAttempt, staleSeen>>

Finalize ==
    /\ outer = "joining"
    /\ \A t \in Tasks: future[t] = "done"
    /\ outer' = "succeeded"
    /\ UNCHANGED <<now, future, current, age, physical, wire,
                    frameValid, objectVersion, capturedVersion,
                    dispatchVersion, acceptedAttempt, staleSeen>>

Next ==
    \/ Finalize
    \/ MutateObject
    \/ \E t \in Tasks: StartAttempt(t) \/ SendTask(t) \/ ReceiveTask(t)
                       \/ DecodeTask(t) \/ DispatchTask(t) \/ Tick(t)
                       \/ Timeout(t) \/ Complete(t) \/ LateComplete(t)
    \/ \E t \in Tasks, a \in Attempts:
          SendResult(t, a) \/ ReceiveResult(t, a) \/ DecodeResult(t, a)
          \/ ResolveResult(t, a) \/ CorruptFrame(t, a) \/ RejectCorrupt(t, a)
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ now \in Nat
    /\ outer \in OuterStates
    /\ future \in [Tasks -> FutureStates]
    /\ current \in [Tasks -> Attempts]
    /\ age \in [Tasks -> 0..TIMEOUT]
    /\ physical \in [Tasks \X Attempts -> PhysicalStates]
    /\ wire \in [Tasks \X Attempts -> WireStates]
    /\ frameValid \in [Tasks \X Attempts -> BOOLEAN]
    /\ objectVersion \in 0..1
    /\ capturedVersion \in [Tasks \X Attempts -> 0..1]
    /\ dispatchVersion \in [Tasks \X Attempts -> 0..1]
    /\ acceptedAttempt \in [Tasks -> Attempts]
    /\ staleSeen \in [Tasks -> BOOLEAN]

RetryBoundSafety == \A t \in Tasks: current[t] <= 1
DependencySafety == outer = "succeeded" => \A t \in Tasks: future[t] = "done"
ResultConsistency ==
    \A t \in Tasks:
        future[t] = "done" =>
            /\ acceptedAttempt[t] = current[t]
            /\ wire[t, current[t]] = "resolved"
StaleResultSafety ==
    \A t \in Tasks: staleSeen[t] =>
        future[t] = "pending" \/ acceptedAttempt[t] = current[t]
RejectedFrameSafety ==
    \A t \in Tasks, a \in Attempts:
        wire[t, a] = "rejected" => future[t] = "pending" \/ a # acceptedAttempt[t]
DispatchSnapshotSafety ==
    \A t \in Tasks, a \in Attempts:
        physical[t, a] = "running" => dispatchVersion[t, a] = capturedVersion[t, a]

=============================================================================
