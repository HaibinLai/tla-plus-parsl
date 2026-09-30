---------------------- MODULE ParslMessageCorrelationThree ----------------------
EXTENDS Naturals, Sequences, FiniteSets

(***************************************************************************
 * Four-task result transport refinement.
 *
 * Each logical task has two physical attempts.  Result envelopes may be
 * emitted late, delivered out of order, duplicated in the queue, or retargeted
 * to another Future.  Resolution must validate both origin and attempt.
 ***************************************************************************)

CONSTANT USE_FIXED

Tasks == {"A", "B", "C", "D"}
Attempts == 0..1
Messages == { [origin |-> t, attempt |-> a] : t \in Tasks, a \in Attempts }
WireStates == {"none", "queued", "inbox", "decoded", "resolved", "stale", "rejected"}

VARIABLES currentAttempt, done, target, wire, tx, rx, future
vars == <<currentAttempt, done, target, wire, tx, rx, future>>

Init ==
    /\ currentAttempt = [t \in Tasks |-> 0]
    /\ done = {}
    /\ target = [m \in Messages |-> m.origin]
    /\ wire = [m \in Messages |-> "none"]
    /\ tx = <<>>
    /\ rx = <<>>
    /\ future = [t \in Tasks |-> "unresolved"]

Complete(t) ==
    /\ t \in Tasks
    /\ [origin |-> t, attempt |-> currentAttempt[t]] \notin done
    /\ done' = done \cup {[origin |-> t, attempt |-> currentAttempt[t]]}
    /\ UNCHANGED <<currentAttempt, target, wire, tx, rx, future>>

Retry(t) ==
    /\ t \in Tasks
    /\ currentAttempt[t] = 0
    /\ future[t] = "unresolved"
    /\ currentAttempt' = [currentAttempt EXCEPT ![t] = 1]
    /\ UNCHANGED <<done, target, wire, tx, rx, future>>

Lose(t) ==
    /\ t \in Tasks
    /\ currentAttempt[t] = 1
    /\ future[t] = "unresolved"
    /\ future' = [future EXCEPT ![t] = "rejected"]
    /\ UNCHANGED <<currentAttempt, done, target, wire, tx, rx>>

LateComplete(t, a) ==
    /\ t \in Tasks
    /\ a \in Attempts
    /\ a < currentAttempt[t]
    /\ done' = done \cup {[origin |-> t, attempt |-> a]}
    /\ UNCHANGED <<currentAttempt, target, wire, tx, rx, future>>

Emit(m) ==
    /\ m \in Messages
    /\ m \in done
    /\ wire[m] = "none"
    /\ Len(tx) < 5
    /\ tx' = Append(tx, m)
    /\ wire' = [wire EXCEPT ![m] = "queued"]
    /\ UNCHANGED <<currentAttempt, done, target, rx, future>>

Retarget(m, t) ==
    /\ m \in Messages
    /\ t \in Tasks
    /\ t # m.origin
    /\ wire[m] = "none"
    /\ target' = [target EXCEPT ![m] = t]
    /\ UNCHANGED <<currentAttempt, done, wire, tx, rx, future>>

Deliver(i) ==
    /\ i \in 1..Len(tx)
    /\ Len(rx) < 5
    /\ LET m == tx[i] IN
        /\ rx' = Append(rx, m)
        /\ wire' = [wire EXCEPT ![m] = "inbox"]
    /\ tx' = SubSeq(tx, 1, i - 1) \o SubSeq(tx, i + 1, Len(tx))
    /\ UNCHANGED <<currentAttempt, done, target, future>>

Decode ==
    /\ Len(rx) > 0
    /\ LET m == Head(rx) IN wire' = [wire EXCEPT ![m] = "decoded"]
    /\ rx' = Tail(rx)
    /\ UNCHANGED <<currentAttempt, done, target, tx, future>>

Resolve(m) ==
    /\ m \in Messages
    /\ wire[m] = "decoded"
    /\ LET t == target[m] IN
        IF USE_FIXED
           THEN IF m.origin # t
                THEN /\ wire' = [wire EXCEPT ![m] = "rejected"]
                     /\ UNCHANGED future
                ELSE IF m.attempt = currentAttempt[t] /\ future[t] = "unresolved"
                     THEN /\ wire' = [wire EXCEPT ![m] = "resolved"]
                          /\ future' = [future EXCEPT ![t] = "resolved"]
                     ELSE /\ wire' = [wire EXCEPT ![m] = "stale"]
                          /\ UNCHANGED future
           ELSE IF m.attempt = currentAttempt[t] /\ future[t] = "unresolved"
                THEN /\ wire' = [wire EXCEPT ![m] = "resolved"]
                     /\ future' = [future EXCEPT ![t] = "resolved"]
                ELSE /\ wire' = [wire EXCEPT ![m] = "stale"]
                     /\ UNCHANGED future
    /\ UNCHANGED <<currentAttempt, done, target, tx, rx>>

Next ==
    \/ \E t \in Tasks : Complete(t) \/ Retry(t) \/ Lose(t)
    \/ \E t \in Tasks, a \in Attempts : LateComplete(t, a)
    \/ \E m \in Messages : Emit(m) \/ Retarget(m, CHOOSE t \in Tasks : t # m.origin)
    \/ \E i \in 1..Len(tx) : Deliver(i)
    \/ Decode
    \/ \E m \in Messages : Resolve(m)
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ currentAttempt \in [Tasks -> Attempts]
    /\ done \subseteq Messages
    /\ target \in [Messages -> Tasks]
    /\ wire \in [Messages -> WireStates]
    /\ tx \in Seq(Messages) /\ Len(tx) <= 5
    /\ rx \in Seq(Messages) /\ Len(rx) <= 5
    /\ future \in [Tasks -> {"unresolved", "resolved", "rejected"}]

CorrelationSafety ==
    \A m \in Messages : wire[m] = "resolved" => target[m] = m.origin

CurrentAttemptSafety ==
    \A t \in Tasks : future[t] = "resolved" =>
        \E m \in Messages : m.origin = t /\ m.attempt = currentAttempt[t]
                             /\ wire[m] = "resolved"

StaleResultSafety ==
    \A m \in Messages : wire[m] = "stale" =>
        \/ m.attempt # currentAttempt[target[m]]
        \/ future[target[m]] # "unresolved"

=============================================================================
CONSTANT USE_FIXED = TRUE

SPECIFICATION Spec

INVARIANTS
    TypeOK
    CorrelationSafety
    CurrentAttemptSafety
    StaleResultSafety
