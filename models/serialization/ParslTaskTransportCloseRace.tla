--------------------------- MODULE ParslTaskTransportCloseRace ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Small cross-layer task transport model.
 *
 * A Python task must pass the serialization boundary before it can be sent by
 * TasksOutgoing. The sender can close while a task is ready or in flight. A
 * current implementation may still call send_pyobj after close; the fixed
 * branch rejects that operation before touching the terminated socket.
 ***************************************************************************)

CONSTANT USE_FIXED

AttemptStates == {"new", "encoding", "ready", "sent", "received", "running",
                  "completed", "rejected", "crashed"}
SenderStates == {"open", "closed"}

VARIABLES attempt, sender, payloadValid, result
vars == <<attempt, sender, payloadValid, result>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ attempt = "new"
    /\ sender = "open"
    /\ payloadValid = TRUE
    /\ result = "none"

BeginEncode ==
    /\ attempt = "new"
    /\ attempt' = "encoding"
    /\ UNCHANGED <<sender, payloadValid, result>>

FinishEncode ==
    /\ attempt = "encoding"
    /\ attempt' = "ready"
    /\ UNCHANGED <<sender, payloadValid, result>>

CorruptPayload ==
    /\ attempt = "encoding"
    /\ payloadValid' = FALSE
    /\ attempt' = "rejected"
    /\ UNCHANGED <<sender, result>>

SendReady ==
    /\ attempt = "ready"
    /\ sender = "open"
    /\ payloadValid
    /\ attempt' = "sent"
    /\ UNCHANGED <<sender, payloadValid, result>>

SendAfterClose ==
    /\ attempt = "ready"
    /\ sender = "closed"
    /\ IF USE_FIXED
          THEN attempt' = "rejected"
          ELSE attempt' = "crashed"
    /\ UNCHANGED <<sender, payloadValid, result>>

CloseSender ==
    /\ sender = "open"
    /\ sender' = "closed"
    /\ UNCHANGED <<attempt, payloadValid, result>>

Receive ==
    /\ attempt = "sent"
    /\ attempt' = "received"
    /\ UNCHANGED <<sender, payloadValid, result>>

Dispatch ==
    /\ attempt = "received"
    /\ payloadValid
    /\ attempt' = "running"
    /\ UNCHANGED <<sender, payloadValid, result>>

Complete ==
    /\ attempt = "running"
    /\ attempt' = "completed"
    /\ result' = "ok"
    /\ UNCHANGED <<sender, payloadValid>>

Next ==
    \/ BeginEncode
    \/ FinishEncode
    \/ CorruptPayload
    \/ SendReady
    \/ SendAfterClose
    \/ CloseSender
    \/ Receive
    \/ Dispatch
    \/ Complete
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ attempt \in AttemptStates
    /\ sender \in SenderStates
    /\ payloadValid \in BOOLEAN
    /\ result \in {"none", "ok"}

SerializationGate ==
    attempt \in {"sent", "received", "running", "completed"} => payloadValid

CloseSafety ==
    attempt # "crashed"

ResultSafety ==
    result = "ok" => attempt = "completed"

=============================================================================
