--------------------------- MODULE ParslMessageCorrelation ---------------------------
EXTENDS Naturals, Sequences, FiniteSets

(***************************************************************************
 * Bounded message reordering and correlation IDs.
 *
 * Two logical tasks may retry independently.  Results can be delivered out
 * of order, duplicated, or routed to the wrong logical Future.  A correct
 * result envelope must match both the logical task ID and the physical
 * attempt ID before it resolves a Future.
 ***************************************************************************)

CONSTANT USE_FIXED

Tasks == {"A", "B"}
Attempts == 0..1
Messages == { [origin |-> t, attempt |-> k] : t \in Tasks, k \in Attempts }
WireStates == {"none", "queued", "inbox", "decoded", "resolved", "stale", "rejected"}
TaskStates == {"running", "lost", "done"}
FutureStates == {"unresolved", "resolved", "rejected"}

VARIABLES currentAttempt, taskState, attemptDone, target, wireState,
          txQueue, rxQueue, futureState
vars == <<currentAttempt, taskState, attemptDone, target, wireState,
           txQueue, rxQueue, futureState>>

Init ==
    /\ currentAttempt = [t \in Tasks |-> 0]
    /\ taskState = [t \in Tasks |-> "running"]
    /\ attemptDone = {}
    /\ target = [m \in Messages |-> m.origin]
    /\ wireState = [m \in Messages |-> "none"]
    /\ txQueue = <<>>
    /\ rxQueue = <<>>
    /\ futureState = [t \in Tasks |-> "unresolved"]

Complete(t) ==
    /\ t \in Tasks
    /\ taskState[t] = "running"
    /\ LET m == [origin |-> t, attempt |-> currentAttempt[t]] IN
        /\ taskState' = [taskState EXCEPT ![t] = "done"]
        /\ attemptDone' = attemptDone \cup {m}
    /\ UNCHANGED <<currentAttempt, target, wireState, txQueue, rxQueue, futureState>>

Lose(t) ==
    /\ t \in Tasks
    /\ taskState[t] = "running"
    /\ currentAttempt[t] < 1
    /\ currentAttempt' = [currentAttempt EXCEPT ![t] = @ + 1]
    /\ taskState' = [taskState EXCEPT ![t] = "running"]
    /\ UNCHANGED <<attemptDone, target, wireState, txQueue, rxQueue, futureState>>

PermanentLose(t) ==
    /\ t \in Tasks
    /\ taskState[t] = "running"
    /\ currentAttempt[t] = 1
    /\ taskState' = [taskState EXCEPT ![t] = "lost"]
    /\ futureState' = [futureState EXCEPT ![t] = "rejected"]
    /\ UNCHANGED <<currentAttempt, attemptDone, target, wireState, txQueue, rxQueue>>

LateComplete(t, k) ==
    /\ t \in Tasks
    /\ k \in Attempts
    /\ k < currentAttempt[t]
    /\ [origin |-> t, attempt |-> k] \notin attemptDone
    /\ attemptDone' = attemptDone \cup {[origin |-> t, attempt |-> k]}
    /\ UNCHANGED <<currentAttempt, taskState, target, wireState, txQueue, rxQueue, futureState>>

Emit(m) ==
    /\ m \in Messages
    /\ m \in attemptDone
    /\ wireState[m] = "none"
    /\ Len(txQueue) < 3
    /\ txQueue' = Append(txQueue, m)
    /\ wireState' = [wireState EXCEPT ![m] = "queued"]
    /\ UNCHANGED <<currentAttempt, taskState, attemptDone, target, rxQueue, futureState>>

Misroute(m, t) ==
    /\ m \in Messages
    /\ t \in Tasks
    /\ t # m.origin
    /\ wireState[m] = "none"
    /\ target' = [target EXCEPT ![m] = t]
    /\ UNCHANGED <<currentAttempt, taskState, attemptDone, wireState, txQueue, rxQueue, futureState>>

Deliver(i) ==
    /\ i \in 1..Len(txQueue)
    /\ Len(rxQueue) < 3
    /\ LET m == txQueue[i] IN
        /\ rxQueue' = Append(rxQueue, m)
        /\ wireState' = [wireState EXCEPT ![m] = "inbox"]
    /\ txQueue' = SubSeq(txQueue, 1, i - 1) \o SubSeq(txQueue, i + 1, Len(txQueue))
    /\ UNCHANGED <<currentAttempt, taskState, attemptDone, target, futureState>>

Decode ==
    /\ Len(rxQueue) > 0
    /\ LET m == Head(rxQueue) IN
        /\ rxQueue' = Tail(rxQueue)
        /\ wireState' = [wireState EXCEPT ![m] = "decoded"]
    /\ UNCHANGED <<currentAttempt, taskState, attemptDone, target, txQueue, futureState>>

Resolve(m) ==
    /\ m \in Messages
    /\ wireState[m] = "decoded"
    /\ LET t == target[m] IN
        /\ IF USE_FIXED
              THEN IF m.origin # t
                   THEN /\ wireState' = [wireState EXCEPT ![m] = "rejected"]
                        /\ UNCHANGED futureState
                   ELSE IF m.attempt = currentAttempt[t] /\ futureState[t] = "unresolved"
                        THEN /\ wireState' = [wireState EXCEPT ![m] = "resolved"]
                             /\ futureState' = [futureState EXCEPT ![t] = "resolved"]
                        ELSE /\ wireState' = [wireState EXCEPT ![m] = "stale"]
                             /\ UNCHANGED futureState
              ELSE IF m.attempt = currentAttempt[t] /\ futureState[t] = "unresolved"
                   THEN /\ wireState' = [wireState EXCEPT ![m] = "resolved"]
                        /\ futureState' = [futureState EXCEPT ![t] = "resolved"]
                   ELSE /\ wireState' = [wireState EXCEPT ![m] = "stale"]
                        /\ UNCHANGED futureState
    /\ UNCHANGED <<currentAttempt, taskState, attemptDone, target, txQueue, rxQueue>>

Next ==
    \/ \E t \in Tasks : Complete(t) \/ Lose(t) \/ PermanentLose(t)
    \/ \E t \in Tasks, k \in Attempts : LateComplete(t, k)
    \/ \E m \in Messages : Emit(m) \/ Misroute(m, CHOOSE t \in Tasks : t # m.origin)
    \/ \E i \in 1..Len(txQueue) : Deliver(i)
    \/ Decode
    \/ \E m \in Messages : Resolve(m)
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ currentAttempt \in [Tasks -> Attempts]
    /\ taskState \in [Tasks -> TaskStates]
    /\ attemptDone \subseteq Messages
    /\ target \in [Messages -> Tasks]
    /\ wireState \in [Messages -> WireStates]
    /\ txQueue \in Seq(Messages)
    /\ rxQueue \in Seq(Messages)
    /\ Len(txQueue) <= 3
    /\ Len(rxQueue) <= 3
    /\ futureState \in [Tasks -> FutureStates]

CorrelationSafety ==
    \A m \in Messages : wireState[m] = "resolved" => target[m] = m.origin

CurrentAttemptSafety ==
    \A t \in Tasks : futureState[t] = "resolved"
        => \E m \in Messages : /\ m.origin = t
                                /\ m.attempt = currentAttempt[t]
                                /\ wireState[m] = "resolved"

StaleResultSafety ==
    \A m \in Messages : wireState[m] = "stale" => m.attempt # currentAttempt[target[m]]

FutureTerminalSafety ==
    \A t \in Tasks : futureState[t] = "resolved" => taskState[t] = "done"

=============================================================================
