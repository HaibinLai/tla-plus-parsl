--------------------------- MODULE ParslZMQ ---------------------------
EXTENDS Naturals, Sequences

CONSTANTS TASKS, MAX_RETRIES, MAX_QUEUE

MESSAGE_KINDS == {"task", "result"}
ENDPOINTS == {"dfk", "manager"}

Message(t, k, kind) ==
    [task      |-> t,
     attempt   |-> k,
     kind      |-> kind,
     sender    |-> IF kind = "task" THEN "dfk" ELSE "manager",
     receiver  |-> IF kind = "task" THEN "manager" ELSE "dfk",
     identity  |-> IF kind = "task" THEN "manager" ELSE "dfk",
     header    |-> "parsl-v1",
     body      |-> "serialized-payload"]

Messages == {Message(t, k, kind) : t \in TASKS,
                                      k \in 0..MAX_RETRIES,
                                      kind \in MESSAGE_KINDS}

VARIABLES linkUp, frameState, routeOK, txQueue, rxQueue,
          seen, accepted, discarded, rejected, acknowledged

vars == <<linkUp, frameState, routeOK, txQueue, rxQueue,
           seen, accepted, discarded, rejected, acknowledged>>

FrameStates == {"none", "header", "body", "ready", "corrupt"}

Init ==
    /\ linkUp = TRUE
    /\ frameState = [m \in Messages |-> "none"]
    /\ routeOK = [m \in Messages |-> TRUE]
    /\ txQueue = <<>>
    /\ rxQueue = <<>>
    /\ seen = {}
    /\ accepted = {}
    /\ discarded = {}
    /\ rejected = {}
    /\ acknowledged = {}

Connect ==
    /\ linkUp = FALSE
    /\ linkUp' = TRUE
    /\ UNCHANGED <<frameState, routeOK, txQueue, rxQueue,
                    seen, accepted, discarded, rejected, acknowledged>>

Disconnect ==
    /\ linkUp = TRUE
    /\ linkUp' = FALSE
    /\ UNCHANGED <<frameState, routeOK, txQueue, rxQueue,
                    seen, accepted, discarded, rejected, acknowledged>>

EncodeHeader(m) ==
    /\ frameState[m] = "none"
    /\ frameState' = [frameState EXCEPT ![m] = "header"]
    /\ UNCHANGED <<linkUp, routeOK, txQueue, rxQueue,
                    seen, accepted, discarded, rejected, acknowledged>>

EncodeBody(m) ==
    /\ frameState[m] = "header"
    /\ frameState' = [frameState EXCEPT ![m] = "body"]
    /\ UNCHANGED <<linkUp, routeOK, txQueue, rxQueue,
                    seen, accepted, discarded, rejected, acknowledged>>

FinishEncode(m) ==
    /\ frameState[m] = "body"
    /\ frameState' = [frameState EXCEPT ![m] = "ready"]
    /\ UNCHANGED <<linkUp, routeOK, txQueue, rxQueue,
                    seen, accepted, discarded, rejected, acknowledged>>

CorruptPayload(m) ==
    /\ frameState[m] = "ready"
    /\ m \notin accepted
    /\ frameState' = [frameState EXCEPT ![m] = "corrupt"]
    /\ UNCHANGED <<linkUp, routeOK, txQueue, rxQueue,
                    seen, accepted, discarded, rejected, acknowledged>>

RepairPayload(m) ==
    /\ frameState[m] = "corrupt"
    /\ frameState' = [frameState EXCEPT ![m] = "ready"]
    /\ UNCHANGED <<linkUp, routeOK, txQueue, rxQueue,
                    seen, accepted, discarded, rejected, acknowledged>>

Misroute(m) ==
    /\ routeOK[m]
    /\ m \notin seen
    /\ routeOK' = [routeOK EXCEPT ![m] = FALSE]
    /\ UNCHANGED <<linkUp, frameState, txQueue, rxQueue,
                    seen, accepted, discarded, rejected, acknowledged>>

RestoreRoute(m) ==
    /\ ~routeOK[m]
    /\ m \notin seen
    /\ routeOK' = [routeOK EXCEPT ![m] = TRUE]
    /\ UNCHANGED <<linkUp, frameState, txQueue, rxQueue,
                    seen, accepted, discarded, rejected, acknowledged>>

Send(m) ==
    /\ linkUp
    /\ frameState[m] = "ready"
    /\ Len(txQueue) < MAX_QUEUE
    /\ txQueue' = Append(txQueue, m)
    /\ UNCHANGED <<linkUp, frameState, routeOK, rxQueue,
                    seen, accepted, discarded, rejected, acknowledged>>

DropOutbound ==
    /\ Len(txQueue) > 0
    /\ txQueue' = Tail(txQueue)
    /\ UNCHANGED <<linkUp, frameState, routeOK, rxQueue,
                    seen, accepted, discarded, rejected, acknowledged>>

Deliver(i) ==
    /\ linkUp
    /\ Len(txQueue) > 0
    /\ i \in 1..Len(txQueue)
    /\ Len(rxQueue) < MAX_QUEUE
    /\ rxQueue' = Append(rxQueue, txQueue[i])
    /\ txQueue' = SubSeq(txQueue, 1, i - 1) 
                    \o SubSeq(txQueue, i + 1, Len(txQueue))
    /\ UNCHANGED <<linkUp, frameState, routeOK,
                    seen, accepted, discarded, rejected, acknowledged>>

DuplicateInbound ==
    /\ Len(rxQueue) > 0
    /\ Len(rxQueue) < MAX_QUEUE
    /\ rxQueue' = Append(rxQueue, Head(rxQueue))
    /\ UNCHANGED <<linkUp, frameState, routeOK, txQueue,
                    seen, accepted, discarded, rejected, acknowledged>>

ReceiveValid ==
    /\ Len(rxQueue) > 0
    /\ LET m == Head(rxQueue) IN
        /\ frameState[m] = "ready"
        /\ routeOK[m]
        /\ m \notin seen
        /\ rxQueue' = Tail(rxQueue)
        /\ seen' = seen \cup {m}
        /\ accepted' = accepted \cup {m}
    /\ UNCHANGED <<linkUp, frameState, routeOK, txQueue,
                    discarded, rejected, acknowledged>>

DiscardDuplicate ==
    /\ Len(rxQueue) > 0
    /\ LET m == Head(rxQueue) IN
        /\ m \in seen
        /\ rxQueue' = Tail(rxQueue)
        /\ discarded' = discarded \cup {m}
    /\ UNCHANGED <<linkUp, frameState, routeOK, txQueue,
                    seen, accepted, rejected, acknowledged>>

RejectInvalid ==
    /\ Len(rxQueue) > 0
    /\ LET m == Head(rxQueue) IN
        /\ (frameState[m] # "ready" \/ ~routeOK[m])
        /\ rxQueue' = Tail(rxQueue)
        /\ rejected' = rejected \cup {m}
    /\ UNCHANGED <<linkUp, frameState, routeOK, txQueue,
                    seen, accepted, discarded, acknowledged>>

Ack(m) ==
    /\ m \in accepted
    /\ m \notin acknowledged
    /\ acknowledged' = acknowledged \cup {m}
    /\ UNCHANGED <<linkUp, frameState, routeOK, txQueue, rxQueue,
                    seen, accepted, discarded, rejected>>

Next ==
    \/ Connect
    \/ Disconnect
    \/ \E m \in Messages : EncodeHeader(m)
    \/ \E m \in Messages : EncodeBody(m)
    \/ \E m \in Messages : FinishEncode(m)
    \/ \E m \in Messages : CorruptPayload(m)
    \/ \E m \in Messages : RepairPayload(m)
    \/ \E m \in Messages : Misroute(m)
    \/ \E m \in Messages : RestoreRoute(m)
    \/ \E m \in Messages : Send(m)
    \/ DropOutbound
    \/ \E i \in 1..Len(txQueue) : Deliver(i)
    \/ DuplicateInbound
    \/ ReceiveValid
    \/ DiscardDuplicate
    \/ RejectInvalid
    \/ \E m \in Messages : Ack(m)

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ linkUp \in BOOLEAN
    /\ frameState \in [Messages -> FrameStates]
    /\ routeOK \in [Messages -> BOOLEAN]
    /\ txQueue \in Seq(Messages)
    /\ rxQueue \in Seq(Messages)
    /\ Len(txQueue) <= MAX_QUEUE
    /\ Len(rxQueue) <= MAX_QUEUE
    /\ seen \subseteq Messages
    /\ accepted \subseteq Messages
    /\ discarded \subseteq Messages
    /\ rejected \subseteq Messages
    /\ acknowledged \subseteq Messages

EnvelopeSafety ==
    /\ accepted \subseteq seen
    /\ acknowledged \subseteq accepted

CorrelationSafety ==
    \A m \in accepted :
        /\ m.header = "parsl-v1"
        /\ m.task \in TASKS
        /\ m.attempt \in 0..MAX_RETRIES
        /\ m.kind \in MESSAGE_KINDS
        /\ m.sender \in ENDPOINTS
        /\ m.receiver \in ENDPOINTS

DuplicateSafety ==
    /\ discarded \subseteq seen

NoCorruptDelivery ==
    \A m \in accepted : frameState[m] = "ready"

=============================================================================
