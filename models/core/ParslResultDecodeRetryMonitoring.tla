--------------------------- MODULE ParslResultDecodeRetryMonitoring ---------------------------
EXTENDS Naturals, Integers, FiniteSets

(***************************************************************************
 * Result decode failure, retry generation, late result delivery, and
 * monitoring persistence in one bounded cross-layer model.
 *
 * The logical task has one Future but may have two physical attempts.  A
 * decode failure closes attempt 0 and permits attempt 1 to start.  Attempt 0
 * may still publish a result after the retry.  Monitoring events can also be
 * persisted out of order.  USE_FIXED rejects the stale result and prevents an
 * older monitoring event from replacing the newer attempt's status.
 ***************************************************************************)

CONSTANT USE_FIXED

Attempts == 0..1
TaskStates == {"pending", "running", "retrying", "resolved"}
AttemptStates == {"absent", "running", "decode_failed", "succeeded", "stale"}
WireStates == {"none", "queued", "consumed"}
MonitorStates == {"none", "running", "decode_failed", "success"}
EventStates == {"running", "decode_failed", "success"}

VARIABLES task, currentAttempt, attemptState, resultWire, resultValid,
          monitorEvents, monitorAttempt, monitorState, futureAttempt

vars == <<task, currentAttempt, attemptState, resultWire, resultValid,
          monitorEvents, monitorAttempt, monitorState, futureAttempt>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ task = "pending"
    /\ currentAttempt = 0
    /\ attemptState = [a \in Attempts |-> "absent"]
    /\ resultWire = [a \in Attempts |-> "none"]
    /\ resultValid = [a \in Attempts |-> TRUE]
    /\ monitorEvents = [a \in Attempts |-> {}]
    /\ monitorAttempt = 0
    /\ monitorState = "none"
    /\ futureAttempt = -1

StartAttempt ==
    /\ task = "pending"
    /\ attemptState[currentAttempt] = "absent"
    /\ task' = "running"
    /\ attemptState' = [attemptState EXCEPT ![currentAttempt] = "running"]
    /\ monitorEvents' = [monitorEvents EXCEPT
          ![currentAttempt] = @ \cup {"running"}]
    /\ UNCHANGED <<currentAttempt, resultWire, resultValid,
                    monitorAttempt, monitorState, futureAttempt>>

DecodeFailure ==
    /\ task = "running"
    /\ attemptState[currentAttempt] = "running"
    /\ task' = "retrying"
    /\ attemptState' = [attemptState EXCEPT ![currentAttempt] = "decode_failed"]
    /\ monitorEvents' = [monitorEvents EXCEPT
          ![currentAttempt] = @ \cup {"decode_failed"}]
    /\ UNCHANGED <<currentAttempt, resultWire, resultValid,
                    monitorAttempt, monitorState, futureAttempt>>

Retry ==
    /\ task = "retrying"
    /\ currentAttempt = 0
    /\ currentAttempt' = 1
    /\ task' = "pending"
    /\ IF USE_FIXED
          THEN /\ monitorAttempt' = 1
               /\ monitorState' = "none"
          ELSE /\ UNCHANGED <<monitorAttempt, monitorState>>
    /\ UNCHANGED <<attemptState, resultWire, resultValid, monitorEvents,
                    futureAttempt>>

CompleteAttempt(a) ==
    /\ a \in Attempts
    /\ attemptState[a] = "running"
    /\ attemptState' = [attemptState EXCEPT ![a] = "succeeded"]
    /\ resultWire' = [resultWire EXCEPT ![a] = "queued"]
    /\ monitorEvents' = [monitorEvents EXCEPT ![a] = @ \cup {"success"}]
    /\ UNCHANGED <<task, currentAttempt, resultValid,
                    monitorAttempt, monitorState, futureAttempt>>

LateComplete(a) ==
    /\ a \in Attempts
    /\ attemptState[a] = "decode_failed"
    /\ resultWire[a] = "none"
    /\ resultWire' = [resultWire EXCEPT ![a] = "queued"]
    /\ monitorEvents' = [monitorEvents EXCEPT ![a] = @ \cup {"success"}]
    /\ UNCHANGED <<task, currentAttempt, attemptState, resultValid,
                    monitorAttempt, monitorState, futureAttempt>>

DeliverResult(a) ==
    /\ a \in Attempts
    /\ resultWire[a] = "queued"
    /\ resultValid[a]
    /\ resultWire' = [resultWire EXCEPT ![a] = "consumed"]
    /\ IF a = currentAttempt /\ task = "running"
          THEN /\ task' = "resolved"
               /\ futureAttempt' = a
               /\ UNCHANGED attemptState
          ELSE IF USE_FIXED
               THEN /\ task' = task
                    /\ futureAttempt' = futureAttempt
                    /\ attemptState' = [attemptState EXCEPT ![a] = "stale"]
               ELSE /\ task' = "resolved"
                    /\ futureAttempt' = a
                    /\ UNCHANGED attemptState
    /\ UNCHANGED <<currentAttempt, resultValid, monitorEvents,
                    monitorAttempt, monitorState>>

PersistMonitor(a, s) ==
    /\ a \in Attempts
    /\ s \in EventStates
    /\ s \in monitorEvents[a]
    /\ ~USE_FIXED \/ a = currentAttempt
    /\ monitorEvents' = [monitorEvents EXCEPT ![a] = @ \ {s}]
    /\ monitorAttempt' = a
    /\ monitorState' = CHOOSE x \in MonitorStates : x = s
    /\ UNCHANGED <<task, currentAttempt, attemptState, resultWire,
                    resultValid, futureAttempt>>

Next ==
    \/ StartAttempt
    \/ DecodeFailure
    \/ Retry
    \/ \E a \in Attempts : CompleteAttempt(a) \/ LateComplete(a) \/ DeliverResult(a)
    \/ \E a \in Attempts, s \in EventStates : PersistMonitor(a, s)
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ task \in TaskStates
    /\ currentAttempt \in Attempts
    /\ attemptState \in [Attempts -> AttemptStates]
    /\ resultWire \in [Attempts -> WireStates]
    /\ resultValid \in [Attempts -> BOOLEAN]
    /\ monitorEvents \in [Attempts -> SUBSET EventStates]
    /\ monitorAttempt \in Attempts
    /\ monitorState \in MonitorStates
    /\ futureAttempt \in -1..1

RetryBound == currentAttempt \in Attempts

DecodeRetrySafety ==
    ~(task = "retrying") \/ attemptState[0] = "decode_failed"

ResultCorrelationSafety ==
    ~(task = "resolved") \/ futureAttempt = currentAttempt

MonitoringHighWaterSafety ==
    ~(monitorAttempt > 0) \/ monitorAttempt = currentAttempt

PersistedSuccessSafety ==
    ~(monitorState = "success") \/ monitorAttempt = currentAttempt

=============================================================================
