--------------------------- MODULE ParslSerializationZMQBridge ---------------------------
EXTENDS Naturals, Sequences, FiniteSets

(***************************************************************************
 * Serialization-to-ZMQ bridge for one logical task with bounded retries.
 *
 * Task and result messages carry an attempt id and serializer token.  The
 * task path must be framed, routed, received, and decoded before dispatch;
 * the result path uses the same receive/decode correlation and can become
 * stale after worker loss selects a retry.
 ***************************************************************************)

CONSTANT MAX_RETRIES
Attempts == 0..MAX_RETRIES
Kinds == {"task", "result"}

Message(k, kind) ==
    [attempt |-> k,
     kind |-> kind,
     sender |-> IF kind = "task" THEN "dfk" ELSE "manager",
     receiver |-> IF kind = "task" THEN "manager" ELSE "dfk",
     token |-> IF kind = "task" THEN "apply:C2/02" ELSE "data:02"]
Messages == {Message(k, kind) : k \in Attempts, kind \in Kinds}

WireStates == {"none", "framed", "invalid", "queued", "received",
               "decoded", "dispatched", "resolved", "stale", "rejected"}
TaskStates == {"none", "running", "done", "lost"}
FutureStates == {"unresolved", "resolved", "rejected"}

VARIABLES wireState, serializable, routeValid, txQueue, rxQueue,
          seen, accepted, discarded, rejected, taskState, workerDone,
          currentAttempt, futureState
vars == <<wireState, serializable, routeValid, txQueue, rxQueue,
           seen, accepted, discarded, rejected, taskState, workerDone,
           currentAttempt, futureState>>

Init ==
    /\ MAX_RETRIES >= 0
    /\ wireState = [m \in Messages |-> "none"]
    /\ serializable = [m \in Messages |-> TRUE]
    /\ routeValid = [m \in Messages |-> TRUE]
    /\ txQueue = <<>>
    /\ rxQueue = <<>>
    /\ seen = {}
    /\ accepted = {}
    /\ discarded = {}
    /\ rejected = {}
    /\ taskState = [k \in Attempts |-> "none"]
    /\ workerDone = [k \in Attempts |-> FALSE]
    /\ currentAttempt = 0
    /\ futureState = "unresolved"

Serialize(m) ==
    /\ wireState[m] = "none"
    /\ serializable[m]
    /\ IF m.kind = "task"
       THEN /\ m.attempt = currentAttempt
            /\ taskState[m.attempt] = "none"
       ELSE /\ taskState[m.attempt] \in {"done", "lost"}
            /\ workerDone[m.attempt]
    /\ wireState' = [wireState EXCEPT ![m] = "framed"]
    /\ UNCHANGED <<serializable, routeValid, txQueue, rxQueue, seen,
                    accepted, discarded, rejected, taskState, workerDone,
                    currentAttempt, futureState>>

SerializationFailure(m) ==
    /\ wireState[m] = "none"
    /\ ~serializable[m]
    /\ wireState' = [wireState EXCEPT ![m] = "invalid"]
    /\ rejected' = rejected \cup {m}
    /\ UNCHANGED <<serializable, routeValid, txQueue, rxQueue, seen,
                    accepted, discarded, taskState, workerDone,
                    currentAttempt, futureState>>

CorruptFrame(m) ==
    /\ wireState[m] = "framed"
    /\ wireState' = [wireState EXCEPT ![m] = "invalid"]
    /\ UNCHANGED <<serializable, routeValid, txQueue, rxQueue, seen,
                    accepted, discarded, rejected, taskState, workerDone,
                    currentAttempt, futureState>>

Misroute(m) ==
    /\ routeValid[m]
    /\ m \notin seen
    /\ routeValid' = [routeValid EXCEPT ![m] = FALSE]
    /\ UNCHANGED <<wireState, serializable, txQueue, rxQueue, seen,
                    accepted, discarded, rejected, taskState, workerDone,
                    currentAttempt, futureState>>

RestoreRoute(m) ==
    /\ ~routeValid[m]
    /\ m \notin seen
    /\ routeValid' = [routeValid EXCEPT ![m] = TRUE]
    /\ UNCHANGED <<wireState, serializable, txQueue, rxQueue, seen,
                    accepted, discarded, rejected, taskState, workerDone,
                    currentAttempt, futureState>>

Send(m) ==
    /\ wireState[m] = "framed"
    /\ Len(txQueue) < 2
    /\ txQueue' = Append(txQueue, m)
    /\ wireState' = [wireState EXCEPT ![m] = "queued"]
    /\ UNCHANGED <<serializable, routeValid, rxQueue, seen, accepted,
                    discarded, rejected, taskState, workerDone,
                    currentAttempt, futureState>>

DropOutbound ==
    /\ Len(txQueue) > 0
    /\ txQueue' = Tail(txQueue)
    /\ UNCHANGED <<wireState, serializable, routeValid, rxQueue, seen,
                    accepted, discarded, rejected, taskState, workerDone,
                    currentAttempt, futureState>>

Deliver(i) ==
    /\ i \in 1..Len(txQueue)
    /\ Len(rxQueue) < 2
    /\ LET m == txQueue[i] IN
        /\ rxQueue' = Append(rxQueue, m)
        /\ wireState' = [wireState EXCEPT ![m] = "received"]
    /\ txQueue' = SubSeq(txQueue, 1, i - 1)
                    \o SubSeq(txQueue, i + 1, Len(txQueue))
    /\ UNCHANGED <<serializable, routeValid, seen, accepted, discarded,
                    rejected, taskState, workerDone,
                    currentAttempt, futureState>>

DuplicateInbound ==
    /\ Len(rxQueue) > 0
    /\ Len(rxQueue) < 2
    /\ rxQueue' = Append(rxQueue, Head(rxQueue))
    /\ UNCHANGED <<wireState, serializable, routeValid, txQueue, seen,
                    accepted, discarded, rejected, taskState, workerDone,
                    currentAttempt, futureState>>

ReceiveNew ==
    /\ Len(rxQueue) > 0
    /\ LET m == Head(rxQueue) IN
        /\ m \notin seen
        /\ routeValid[m]
        /\ wireState[m] = "received"
        /\ rxQueue' = Tail(rxQueue)
        /\ seen' = seen \cup {m}
        /\ accepted' = accepted \cup {m}
    /\ UNCHANGED <<wireState, serializable, routeValid, txQueue,
                    discarded, rejected, taskState, workerDone,
                    currentAttempt, futureState>>

DiscardDuplicate ==
    /\ Len(rxQueue) > 0
    /\ LET m == Head(rxQueue) IN
        /\ m \in seen
        /\ rxQueue' = Tail(rxQueue)
        /\ discarded' = discarded \cup {m}
    /\ UNCHANGED <<wireState, serializable, routeValid, txQueue, seen,
                    accepted, rejected, taskState, workerDone,
                    currentAttempt, futureState>>

RejectInbound ==
    /\ Len(rxQueue) > 0
    /\ LET m == Head(rxQueue) IN
        /\ m \notin seen
        /\ ~routeValid[m]
        /\ rxQueue' = Tail(rxQueue)
        /\ rejected' = rejected \cup {m}
        /\ wireState' = [wireState EXCEPT ![m] = "rejected"]
    /\ UNCHANGED <<serializable, routeValid, txQueue, seen, accepted,
                    discarded, taskState, workerDone,
                    currentAttempt, futureState>>

Decode(m) ==
    /\ m \in accepted
    /\ wireState[m] = "received"
    /\ wireState' = [wireState EXCEPT ![m] = "decoded"]
    /\ UNCHANGED <<serializable, routeValid, txQueue, rxQueue, seen,
                    accepted, discarded, rejected, taskState, workerDone,
                    currentAttempt, futureState>>

DispatchTask(m) ==
    /\ m.kind = "task"
    /\ m.attempt = currentAttempt
    /\ wireState[m] = "decoded"
    /\ taskState' = [taskState EXCEPT ![m.attempt] = "running"]
    /\ wireState' = [wireState EXCEPT ![m] = "dispatched"]
    /\ UNCHANGED <<serializable, routeValid, txQueue, rxQueue, seen,
                    accepted, discarded, rejected, workerDone,
                    currentAttempt, futureState>>

WorkerComplete(k) ==
    /\ taskState[k] = "running"
    /\ taskState' = [taskState EXCEPT ![k] = "done"]
    /\ workerDone' = [workerDone EXCEPT ![k] = TRUE]
    /\ UNCHANGED <<wireState, serializable, routeValid, txQueue, rxQueue,
                    seen, accepted, discarded, rejected,
                    currentAttempt, futureState>>

LoseCurrent ==
    /\ taskState[currentAttempt] = "running"
    /\ taskState' = [taskState EXCEPT ![currentAttempt] = "lost"]
    /\ IF currentAttempt < MAX_RETRIES
       THEN /\ currentAttempt' = currentAttempt + 1
            /\ futureState' = futureState
       ELSE /\ currentAttempt' = currentAttempt
            /\ futureState' = "rejected"
    /\ UNCHANGED <<wireState, serializable, routeValid, txQueue, rxQueue,
                    seen, accepted, discarded, rejected, workerDone>>

LateWorkerComplete(k) ==
    /\ taskState[k] = "lost"
    /\ ~workerDone[k]
    /\ taskState' = [taskState EXCEPT ![k] = "done"]
    /\ workerDone' = [workerDone EXCEPT ![k] = TRUE]
    /\ UNCHANGED <<wireState, serializable, routeValid, txQueue, rxQueue,
                    seen, accepted, discarded, rejected,
                    currentAttempt, futureState>>

ResolveResult(m) ==
    /\ m.kind = "result"
    /\ wireState[m] = "decoded"
    /\ wireState' = [wireState EXCEPT ![m] =
          IF m.attempt = currentAttempt /\ futureState = "unresolved"
          THEN "resolved" ELSE "stale"]
    /\ futureState' = IF m.attempt = currentAttempt /\ futureState = "unresolved"
                      THEN "resolved" ELSE futureState
    /\ UNCHANGED <<serializable, routeValid, txQueue, rxQueue,
                    seen, accepted, discarded, rejected, taskState,
                    workerDone, currentAttempt>>

Next ==
    \/ \E m \in Messages : Serialize(m) \/ SerializationFailure(m)
    \/ \E m \in Messages : CorruptFrame(m) \/ Misroute(m) \/ RestoreRoute(m)
    \/ \E m \in Messages : Send(m)
    \/ DropOutbound
    \/ \E i \in 1..Len(txQueue) : Deliver(i)
    \/ DuplicateInbound
    \/ ReceiveNew \/ DiscardDuplicate \/ RejectInbound
    \/ \E m \in Messages : Decode(m) \/ DispatchTask(m) \/ ResolveResult(m)
    \/ \E k \in Attempts : WorkerComplete(k) \/ LateWorkerComplete(k)
    \/ LoseCurrent
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ wireState \in [Messages -> WireStates]
    /\ serializable \in [Messages -> BOOLEAN]
    /\ routeValid \in [Messages -> BOOLEAN]
    /\ txQueue \in Seq(Messages)
    /\ rxQueue \in Seq(Messages)
    /\ Len(txQueue) <= 2
    /\ Len(rxQueue) <= 2
    /\ seen \subseteq Messages
    /\ accepted \subseteq Messages
    /\ discarded \subseteq Messages
    /\ rejected \subseteq Messages
    /\ taskState \in [Attempts -> TaskStates]
    /\ workerDone \in [Attempts -> BOOLEAN]
    /\ currentAttempt \in Attempts
    /\ futureState \in FutureStates

CorrelationSafety ==
    \A m \in accepted :
        /\ m.token \in {"apply:C2/02", "data:02"}
        /\ m.attempt \in Attempts
        /\ m.sender \in {"dfk", "manager"}
        /\ m.receiver \in {"dfk", "manager"}

DispatchSafety ==
    \A m \in Messages : wireState[m] = "dispatched"
        => /\ m.kind = "task"
           /\ m.attempt = currentAttempt \/ taskState[m.attempt] \in {"running", "done", "lost"}
           /\ m \in accepted

DecodeSafety ==
    \A m \in Messages : wireState[m] \in {"decoded", "dispatched", "resolved", "stale"}
        => /\ m \in accepted
           /\ serializable[m]
           /\ routeValid[m]

StaleSafety ==
    \A m \in Messages : wireState[m] = "stale"
        => m.kind = "result" /\ (m.attempt # currentAttempt \/ futureState # "unresolved")

FutureSafety ==
    futureState = "resolved" =>
        \E m \in Messages : m.kind = "result" /\ wireState[m] = "resolved"

=============================================================================
