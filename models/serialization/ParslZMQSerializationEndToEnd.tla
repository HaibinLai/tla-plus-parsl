--------------------------- MODULE ParslZMQSerializationEndToEnd ---------------------------
EXTENDS Naturals, Sequences, FiniteSets

(***************************************************************************
 * A bounded ZMQ + serializer + attempt-correlation protocol.
 *
 * Task and result messages use the concrete default serializer identifiers
 * C2 and 02.  Multipart frames must be serialized, framed, routed, received,
 * and decoded before dispatch.  A result for an old attempt is stale; the
 * current branch incorrectly resolves the Future with it.  The wire payload
 * can also be corrupted after framing; fixed decoding rejects that frame.
 ***************************************************************************)

CONSTANTS MAX_RETRIES, USE_FIXED

Attempts == 0..MAX_RETRIES
Kinds == {"task", "result"}
FrameStates == {"none", "serialized", "framed", "queued", "received", "decoded",
                "dispatched", "resolved", "stale", "rejected"}
TaskStates == {"none", "running", "done", "lost"}
FutureStates == {"unresolved", "resolved", "rejected"}

Message(k, kind) ==
    [attempt |-> k,
     kind |-> kind,
     header |-> IF kind = "task" THEN "C2" ELSE "02",
     sender |-> IF kind = "task" THEN "dfk" ELSE "manager",
     receiver |-> IF kind = "task" THEN "manager" ELSE "dfk"]
Messages == {Message(k, kind) : k \in Attempts, kind \in Kinds}

VARIABLES frameState, routeOK, payloadOK, txQueue, rxQueue, seen, discarded, rejected,
          taskState, workerDone, currentAttempt, futureState

vars == <<frameState, routeOK, payloadOK, txQueue, rxQueue, seen, discarded, rejected,
           taskState, workerDone, currentAttempt, futureState>>

Init ==
    /\ MAX_RETRIES >= 0
    /\ frameState = [m \in Messages |-> "none"]
    /\ routeOK = [m \in Messages |-> TRUE]
    /\ payloadOK = [m \in Messages |-> TRUE]
    /\ txQueue = <<>>
    /\ rxQueue = <<>>
    /\ seen = {}
    /\ discarded = {}
    /\ rejected = {}
    /\ taskState = [k \in Attempts |-> "none"]
    /\ workerDone = [k \in Attempts |-> FALSE]
    /\ currentAttempt = 0
    /\ futureState = "unresolved"

Encode(m) ==
    /\ frameState[m] = "none"
    /\ IF m.kind = "task"
       THEN /\ m.attempt = currentAttempt
            /\ taskState[m.attempt] = "none"
       ELSE /\ taskState[m.attempt] \in {"done", "lost"}
            /\ workerDone[m.attempt]
    /\ frameState' = [frameState EXCEPT ![m] = "serialized"]
    /\ UNCHANGED <<routeOK, txQueue, rxQueue, seen, discarded, rejected,
                    taskState, workerDone, currentAttempt, futureState>>

Frame(m) ==
    /\ frameState[m] = "serialized"
    /\ frameState' = [frameState EXCEPT ![m] = "framed"]
    /\ UNCHANGED <<routeOK, txQueue, rxQueue, seen, discarded, rejected,
                    taskState, workerDone, currentAttempt, futureState>>

Misroute(m) ==
    /\ routeOK[m]
    /\ m \notin seen
    /\ routeOK' = [routeOK EXCEPT ![m] = FALSE]
    /\ UNCHANGED <<frameState, txQueue, rxQueue, seen, discarded, rejected,
                    taskState, workerDone, currentAttempt, futureState>>

RestoreRoute(m) ==
    /\ ~routeOK[m]
    /\ m \notin seen
    /\ routeOK' = [routeOK EXCEPT ![m] = TRUE]
    /\ UNCHANGED <<frameState, txQueue, rxQueue, seen, discarded, rejected,
                    taskState, workerDone, currentAttempt, futureState>>

Send(m) ==
    /\ frameState[m] = "framed"
    /\ Len(txQueue) < 2
    /\ txQueue' = Append(txQueue, m)
    /\ frameState' = [frameState EXCEPT ![m] = "queued"]
    /\ UNCHANGED <<routeOK, rxQueue, seen, discarded, rejected,
                    taskState, workerDone, currentAttempt, futureState>>

DropOutbound ==
    /\ Len(txQueue) > 0
    /\ txQueue' = Tail(txQueue)
    /\ UNCHANGED <<frameState, routeOK, rxQueue, seen, discarded, rejected,
                    taskState, workerDone, currentAttempt, futureState>>

Deliver(i) ==
    /\ i \in 1..Len(txQueue)
    /\ Len(rxQueue) < 2
    /\ LET m == txQueue[i] IN
        /\ frameState[m] = "queued"
        /\ rxQueue' = Append(rxQueue, m)
        /\ frameState' = [frameState EXCEPT ![m] = "received"]
    /\ txQueue' = SubSeq(txQueue, 1, i - 1)
                    \o SubSeq(txQueue, i + 1, Len(txQueue))
    /\ UNCHANGED <<routeOK, seen, discarded, rejected, taskState,
                    workerDone, currentAttempt, futureState>>

DuplicateInbound ==
    /\ Len(rxQueue) > 0
    /\ Len(rxQueue) < 2
    /\ rxQueue' = Append(rxQueue, Head(rxQueue))
    /\ UNCHANGED <<frameState, routeOK, txQueue, seen, discarded, rejected,
                    taskState, workerDone, currentAttempt, futureState>>

Receive ==
    /\ Len(rxQueue) > 0
    /\ LET m == Head(rxQueue) IN
        /\ rxQueue' = Tail(rxQueue)
        /\ IF m \in seen
           THEN /\ discarded' = discarded \cup {m}
                /\ UNCHANGED <<seen, rejected, frameState>>
           ELSE IF routeOK[m]
                THEN /\ seen' = seen \cup {m}
                     /\ frameState' = [frameState EXCEPT ![m] = "received"]
                     /\ UNCHANGED <<discarded, rejected>>
                ELSE /\ rejected' = rejected \cup {m}
                     /\ frameState' = [frameState EXCEPT ![m] = "rejected"]
                     /\ UNCHANGED <<seen, discarded>>
    /\ UNCHANGED <<routeOK, txQueue, taskState, workerDone,
                    currentAttempt, futureState>>

Decode(m) ==
    /\ m \in seen
    /\ frameState[m] = "received"
    /\ frameState' = [frameState EXCEPT ![m] =
          IF payloadOK[m] \/ ~USE_FIXED THEN "decoded" ELSE "rejected"]
    /\ UNCHANGED <<routeOK, txQueue, rxQueue, seen, discarded, rejected,
                    taskState, workerDone, currentAttempt, futureState>>

DispatchTask(m) ==
    /\ m.kind = "task"
    /\ m.attempt = currentAttempt
    /\ frameState[m] = "decoded"
    /\ frameState' = [frameState EXCEPT ![m] = "dispatched"]
    /\ taskState' = [taskState EXCEPT ![m.attempt] = "running"]
    /\ UNCHANGED <<routeOK, txQueue, rxQueue, seen, discarded, rejected,
                    workerDone, currentAttempt, futureState>>

WorkerComplete(k) ==
    /\ taskState[k] = "running"
    /\ taskState' = [taskState EXCEPT ![k] = "done"]
    /\ workerDone' = [workerDone EXCEPT ![k] = TRUE]
    /\ UNCHANGED <<frameState, routeOK, txQueue, rxQueue, seen,
                    discarded, rejected, currentAttempt, futureState>>

LoseCurrent ==
    /\ taskState[currentAttempt] = "running"
    /\ taskState' = [taskState EXCEPT ![currentAttempt] = "lost"]
    /\ IF currentAttempt < MAX_RETRIES
       THEN /\ currentAttempt' = currentAttempt + 1
            /\ futureState' = futureState
       ELSE /\ currentAttempt' = currentAttempt
            /\ futureState' = "rejected"
    /\ UNCHANGED <<frameState, routeOK, txQueue, rxQueue, seen,
                    discarded, rejected, workerDone>>

LateWorkerComplete(k) ==
    /\ taskState[k] = "lost"
    /\ ~workerDone[k]
    /\ taskState' = [taskState EXCEPT ![k] = "done"]
    /\ workerDone' = [workerDone EXCEPT ![k] = TRUE]
    /\ UNCHANGED <<frameState, routeOK, txQueue, rxQueue, seen,
                    discarded, rejected, currentAttempt, futureState>>

ResolveResult(m) ==
    /\ m.kind = "result"
    /\ frameState[m] = "decoded"
    /\ IF m.attempt = currentAttempt /\ futureState = "unresolved"
       THEN /\ frameState' = [frameState EXCEPT ![m] = "resolved"]
            /\ futureState' = "resolved"
       ELSE IF USE_FIXED
            THEN /\ frameState' = [frameState EXCEPT ![m] = "stale"]
                 /\ futureState' = futureState
            ELSE /\ frameState' = [frameState EXCEPT ![m] = "resolved"]
                 /\ futureState' = "resolved"
    /\ UNCHANGED <<routeOK, txQueue, rxQueue, seen, discarded, rejected,
                    taskState, workerDone, currentAttempt>>

CorruptPayload(m) ==
    /\ m \in Messages
    /\ m.kind = "result"
    /\ frameState[m] = "framed"
    /\ payloadOK[m]
    /\ payloadOK' = [payloadOK EXCEPT ![m] = FALSE]
    /\ UNCHANGED <<frameState, routeOK, txQueue, rxQueue, seen, discarded,
                    rejected, taskState, workerDone, currentAttempt,
                    futureState>>

CoreNext ==
    \/ \E m \in Messages : Encode(m) \/ Frame(m)
    \/ \E m \in Messages : Misroute(m) \/ RestoreRoute(m)
    \/ \E m \in Messages : Send(m)
    \/ DropOutbound
    \/ \E i \in 1..Len(txQueue) : Deliver(i)
    \/ DuplicateInbound
    \/ Receive
    \/ \E m \in Messages : Decode(m) \/ DispatchTask(m) \/ ResolveResult(m)
    \/ \E k \in Attempts : WorkerComplete(k) \/ LateWorkerComplete(k)
    \/ LoseCurrent
    \/ UNCHANGED vars

Next ==
    \/ (CoreNext /\ UNCHANGED payloadOK)
    \/ \E m \in Messages : CorruptPayload(m)

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ frameState \in [Messages -> FrameStates]
    /\ routeOK \in [Messages -> BOOLEAN]
    /\ payloadOK \in [Messages -> BOOLEAN]
    /\ txQueue \in Seq(Messages)
    /\ rxQueue \in Seq(Messages)
    /\ Len(txQueue) <= 2
    /\ Len(rxQueue) <= 2
    /\ seen \subseteq Messages
    /\ discarded \subseteq Messages
    /\ rejected \subseteq Messages
    /\ taskState \in [Attempts -> TaskStates]
    /\ workerDone \in [Attempts -> BOOLEAN]
    /\ currentAttempt \in Attempts
    /\ futureState \in FutureStates

FrameSafety ==
    \A m \in Messages : frameState[m] \in {"decoded", "dispatched", "resolved", "stale"}
        => /\ m \in seen
           /\ m.header \in {"C2", "02"}
           /\ routeOK[m]

PayloadIntegritySafety ==
    \A m \in Messages : frameState[m] \in {"decoded", "dispatched", "resolved", "stale"}
        => payloadOK[m]

DispatchSafety ==
    \A m \in Messages : frameState[m] = "dispatched"
        => /\ m.kind = "task"
           /\ (m.attempt = currentAttempt \/ taskState[m.attempt] \in {"running", "done", "lost"})
           /\ m \in seen

ResultCorrelationSafety ==
    \A m \in Messages : frameState[m] = "resolved"
        => /\ m.kind = "result"
           /\ m.attempt = currentAttempt

StaleResultSafety ==
    \A m \in Messages : frameState[m] = "stale"
        => m.kind = "result"
           /\ (m.attempt # currentAttempt \/ futureState \in {"resolved", "rejected"})

FutureSafety ==
    futureState = "resolved" =>
        \E m \in Messages : m.kind = "result" /\ frameState[m] = "resolved"

TerminalResultSafety ==
    futureState = "rejected" =>
        \A m \in Messages : frameState[m] # "resolved"

=============================================================================
