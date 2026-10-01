--------------------------- MODULE ParslTaskTransport ---------------------------
EXTENDS Naturals, Sequences, FiniteSets

(***************************************************************************
 * Cross-component task/result protocol.
 *
 * This small model connects Python object-graph serialization to the bounded
 * ZMQ-like task/result lifecycle.  A physical attempt must finish encoding
 * before transport, and a result from an obsolete attempt is stale even if it
 * arrives after a retry has started.
 ***************************************************************************)

CONSTANTS OBJECTS, TASK_OBJECTS, SERIALIZABLE_OBJECTS, MAX_RETRIES

AttemptIds == 0..MAX_RETRIES
AttemptStates == {"none", "encoding", "header", "body", "ready", "sent",
                  "received", "decoded", "running", "completed", "lost",
                  "rejected"}
ResultStates == {"none", "ready", "sent", "received", "accepted", "stale", "rejected"}
EnvelopeStates == {"none", "valid", "invalid"}
FutureStates == {"unresolved", "resolved", "rejected"}
FailureCauses == {"none", "serialization", "protocol", "worker"}

ObjectGraphSerializable ==
    TASK_OBJECTS \subseteq SERIALIZABLE_OBJECTS

VARIABLES currentAttempt, futureState, attemptState,
          taskEnvelope, resultEnvelope, resultState,
          payloadValid, resultValid, failureCause

vars == <<currentAttempt, futureState, attemptState,
           taskEnvelope, resultEnvelope, resultState,
           payloadValid, resultValid, failureCause>>

Init ==
    /\ OBJECTS # {}
    /\ TASK_OBJECTS \subseteq OBJECTS
    /\ SERIALIZABLE_OBJECTS \subseteq OBJECTS
    /\ MAX_RETRIES >= 0
    /\ currentAttempt = 0
    /\ futureState = "unresolved"
    /\ attemptState = [k \in AttemptIds |-> "none"]
    /\ taskEnvelope = [k \in AttemptIds |-> "none"]
    /\ resultEnvelope = [k \in AttemptIds |-> "none"]
    /\ resultState = [k \in AttemptIds |-> "none"]
    /\ payloadValid = [k \in AttemptIds |-> TRUE]
    /\ resultValid = [k \in AttemptIds |-> TRUE]
    /\ failureCause = [k \in AttemptIds |-> "none"]

BeginEncode(k) ==
    /\ k = currentAttempt
    /\ futureState = "unresolved"
    /\ attemptState[k] = "none"
    /\ attemptState' = [attemptState EXCEPT ![k] = "encoding"]
    /\ UNCHANGED <<currentAttempt, futureState, taskEnvelope,
                    resultEnvelope, resultState, payloadValid,
                    resultValid, failureCause>>

EncodeHeader(k) ==
    /\ attemptState[k] = "encoding"
    /\ attemptState' = [attemptState EXCEPT ![k] = "header"]
    /\ UNCHANGED <<currentAttempt, futureState, taskEnvelope,
                    resultEnvelope, resultState, payloadValid,
                    resultValid, failureCause>>

EncodeBody(k) ==
    /\ attemptState[k] = "header"
    /\ attemptState' = [attemptState EXCEPT ![k] = "body"]
    /\ UNCHANGED <<currentAttempt, futureState, taskEnvelope,
                    resultEnvelope, resultState, payloadValid,
                    resultValid, failureCause>>

FinishEncodeSuccess(k) ==
    /\ attemptState[k] = "body"
    /\ ObjectGraphSerializable
    /\ payloadValid[k]
    /\ attemptState' = [attemptState EXCEPT ![k] = "ready"]
    /\ taskEnvelope' = [taskEnvelope EXCEPT ![k] = "valid"]
    /\ UNCHANGED <<currentAttempt, futureState, resultEnvelope,
                    resultState, payloadValid, resultValid, failureCause>>

FinishEncodeFailure(k) ==
    /\ attemptState[k] = "body"
    /\ (~ObjectGraphSerializable \/ ~payloadValid[k])
    /\ attemptState' = [attemptState EXCEPT ![k] = "rejected"]
    /\ taskEnvelope' = [taskEnvelope EXCEPT ![k] = "invalid"]
    /\ failureCause' = [failureCause EXCEPT ![k] = "serialization"]
    /\ UNCHANGED <<currentAttempt, futureState, resultEnvelope,
                    resultState, payloadValid, resultValid>>

CorruptPayload(k) ==
    /\ attemptState[k] = "body"
    /\ payloadValid' = [payloadValid EXCEPT ![k] = FALSE]
    /\ UNCHANGED <<currentAttempt, futureState, attemptState,
                    taskEnvelope, resultEnvelope, resultState,
                    resultValid, failureCause>>

SendTask(k) ==
    /\ attemptState[k] = "ready"
    /\ taskEnvelope[k] = "valid"
    /\ attemptState' = [attemptState EXCEPT ![k] = "sent"]
    /\ UNCHANGED <<currentAttempt, futureState, taskEnvelope,
                    resultEnvelope, resultState, payloadValid,
                    resultValid, failureCause>>

CorruptTaskEnvelope(k) ==
    /\ attemptState[k] \in {"sent", "received"}
    /\ taskEnvelope' = [taskEnvelope EXCEPT ![k] = "invalid"]
    /\ UNCHANGED <<currentAttempt, futureState, attemptState,
                    resultEnvelope, resultState, payloadValid,
                    resultValid, failureCause>>

DeliverTask(k) ==
    /\ attemptState[k] = "sent"
    /\ attemptState' = [attemptState EXCEPT ![k] = "received"]
    /\ UNCHANGED <<currentAttempt, futureState, taskEnvelope,
                    resultEnvelope, resultState, payloadValid,
                    resultValid, failureCause>>

DecodeTaskSuccess(k) ==
    /\ attemptState[k] = "received"
    /\ taskEnvelope[k] = "valid"
    /\ payloadValid[k]
    /\ attemptState' = [attemptState EXCEPT ![k] = "decoded"]
    /\ UNCHANGED <<currentAttempt, futureState, taskEnvelope,
                    resultEnvelope, resultState, payloadValid,
                    resultValid, failureCause>>

DecodeTaskFailure(k) ==
    /\ attemptState[k] = "received"
    /\ (~(taskEnvelope[k] = "valid") \/ ~payloadValid[k])
    /\ attemptState' = [attemptState EXCEPT ![k] = "rejected"]
    /\ failureCause' = [failureCause EXCEPT ![k] = "protocol"]
    /\ UNCHANGED <<currentAttempt, futureState, taskEnvelope,
                    resultEnvelope, resultState, payloadValid, resultValid>>

DispatchTask(k) ==
    /\ k = currentAttempt
    /\ attemptState[k] = "decoded"
    /\ taskEnvelope[k] = "valid"
    /\ attemptState' = [attemptState EXCEPT ![k] = "running"]
    /\ UNCHANGED <<currentAttempt, futureState, taskEnvelope,
                    resultEnvelope, resultState, payloadValid,
                    resultValid, failureCause>>

CompleteTask(k) ==
    /\ attemptState[k] = "running"
    /\ attemptState' = [attemptState EXCEPT ![k] = "completed"]
    /\ resultState' = [resultState EXCEPT ![k] = "ready"]
    /\ resultEnvelope' = [resultEnvelope EXCEPT ![k] = "valid"]
    /\ UNCHANGED <<currentAttempt, futureState, taskEnvelope,
                    payloadValid, resultValid, failureCause>>

LoseAttempt(k) ==
    /\ k = currentAttempt
    /\ attemptState[k] \in {"running", "completed"}
    /\ attemptState' = [attemptState EXCEPT ![k] = "lost"]
    /\ failureCause' = [failureCause EXCEPT ![k] = "worker"]
    /\ UNCHANGED <<currentAttempt, futureState, taskEnvelope,
                    resultEnvelope, resultState, payloadValid, resultValid>>

RetryTask ==
    /\ futureState = "unresolved"
    /\ attemptState[currentAttempt] \in {"rejected", "lost"}
    /\ currentAttempt < MAX_RETRIES
    /\ currentAttempt' = currentAttempt + 1
    /\ UNCHANGED <<futureState, attemptState, taskEnvelope,
                    resultEnvelope, resultState, payloadValid,
                    resultValid, failureCause>>

SendResult(k) ==
    /\ resultState[k] = "ready"
    /\ resultValid[k]
    /\ resultState' = [resultState EXCEPT ![k] = "sent"]
    /\ UNCHANGED <<currentAttempt, futureState, attemptState,
                    taskEnvelope, resultEnvelope, payloadValid,
                    resultValid, failureCause>>

RejectResult(k) ==
    /\ resultState[k] = "ready"
    /\ ~resultValid[k]
    /\ resultState' = [resultState EXCEPT ![k] = "rejected"]
    /\ UNCHANGED <<currentAttempt, futureState, attemptState,
                    taskEnvelope, resultEnvelope, payloadValid,
                    resultValid, failureCause>>

CorruptResult(k) ==
    /\ resultState[k] = "ready"
    /\ resultValid' = [resultValid EXCEPT ![k] = FALSE]
    /\ UNCHANGED <<currentAttempt, futureState, attemptState,
                    taskEnvelope, resultEnvelope, resultState,
                    payloadValid, failureCause>>

DeliverResult(k) ==
    /\ resultState[k] = "sent"
    /\ resultState' = [resultState EXCEPT ![k] = "received"]
    /\ UNCHANGED <<currentAttempt, futureState, attemptState,
                    taskEnvelope, resultEnvelope, payloadValid,
                    resultValid, failureCause>>

AcceptResult(k) ==
    /\ resultState[k] = "received"
    /\ resultEnvelope[k] = "valid"
    /\ resultValid[k]
    /\ resultState' = [resultState EXCEPT ![k] =
          IF k = currentAttempt /\ futureState = "unresolved"
          THEN "accepted" ELSE "stale"]
    /\ futureState' = IF k = currentAttempt /\ futureState = "unresolved"
                      THEN "resolved" ELSE futureState
    /\ UNCHANGED <<currentAttempt, attemptState, taskEnvelope,
                    resultEnvelope, payloadValid, resultValid, failureCause>>

RejectFinalAttempt ==
    /\ futureState = "unresolved"
    /\ currentAttempt = MAX_RETRIES
    /\ attemptState[currentAttempt] = "rejected"
    /\ futureState' = "rejected"
    /\ UNCHANGED <<currentAttempt, attemptState, taskEnvelope,
                    resultEnvelope, resultState, payloadValid,
                    resultValid, failureCause>>

Next ==
    \/ \E k \in AttemptIds : BeginEncode(k) \/ EncodeHeader(k)
    \/ \E k \in AttemptIds : EncodeBody(k) \/ FinishEncodeSuccess(k)
    \/ \E k \in AttemptIds : FinishEncodeFailure(k)
    \/ \E k \in AttemptIds : CorruptPayload(k) \/ SendTask(k)
    \/ \E k \in AttemptIds : CorruptTaskEnvelope(k) \/ DeliverTask(k)
    \/ \E k \in AttemptIds : DecodeTaskSuccess(k) \/ DispatchTask(k)
    \/ \E k \in AttemptIds : DecodeTaskFailure(k)
    \/ \E k \in AttemptIds : CompleteTask(k) \/ LoseAttempt(k)
    \/ RetryTask
    \/ \E k \in AttemptIds : SendResult(k) \/ RejectResult(k)
    \/ \E k \in AttemptIds : CorruptResult(k)
    \/ \E k \in AttemptIds : DeliverResult(k) \/ AcceptResult(k)
    \/ RejectFinalAttempt
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ currentAttempt \in AttemptIds
    /\ futureState \in FutureStates
    /\ attemptState \in [AttemptIds -> AttemptStates]
    /\ taskEnvelope \in [AttemptIds -> EnvelopeStates]
    /\ resultEnvelope \in [AttemptIds -> EnvelopeStates]
    /\ resultState \in [AttemptIds -> ResultStates]
    /\ payloadValid \in [AttemptIds -> BOOLEAN]
    /\ resultValid \in [AttemptIds -> BOOLEAN]
    /\ failureCause \in [AttemptIds -> FailureCauses]

SerializationDispatchSafety ==
    \A k \in AttemptIds :
        attemptState[k] \in {"decoded", "running", "completed", "lost"}
        => /\ taskEnvelope[k] = "valid"
           /\ payloadValid[k]
           /\ ObjectGraphSerializable

TransportOrderSafety ==
    \A k \in AttemptIds :
        attemptState[k] \in {"decoded", "running",
                              "completed", "lost"}
        => taskEnvelope[k] = "valid"

ResultCorrelationSafety ==
    /\ \A k \in AttemptIds :
          resultState[k] = "accepted" =>
             /\ k = currentAttempt
             /\ futureState = "resolved"
    /\ \A k \in AttemptIds :
          resultState[k] = "stale" => k # currentAttempt \/ futureState # "unresolved"

RetryBoundSafety == currentAttempt \in AttemptIds

FutureResolutionSafety ==
    futureState = "resolved" => resultState[currentAttempt] = "accepted"

ResultDecodeSafety ==
    /\ \A k \in AttemptIds :
          resultState[k] = "accepted" =>
             /\ resultEnvelope[k] = "valid"
             /\ resultValid[k]

=============================================================================
