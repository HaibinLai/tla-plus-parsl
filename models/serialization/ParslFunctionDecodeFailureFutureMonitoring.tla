--------------------------- MODULE ParslFunctionDecodeFailureFutureMonitoring ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Python callable/object decode failure composed with Future monitoring.
 *
 * Function and argument bytes are serialized before source mutation.  If
 * worker-side decoding fails, the Current branch leaves the logical task and
 * Future pending after marking only the transport failure.  The Fixed branch
 * propagates that decode failure to task, Future, and monitoring state.
 ***************************************************************************)

CONSTANTS DECODE_FAILS, USE_FIXED

States == {"new", "encoded", "decoding", "decoded", "failed"}
TaskStates == {"pending", "failed", "succeeded"}
FutureStates == {"pending", "failed", "succeeded"}
MonitorStates == {"none", "failed", "succeeded"}

VARIABLES sourceValue, capturedValue, state, task, future, monitor
vars == <<sourceValue, capturedValue, state, task, future, monitor>>

Init ==
    /\ DECODE_FAILS \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ sourceValue = 1
    /\ capturedValue = 0
    /\ state = "new"
    /\ task = "pending"
    /\ future = "pending"
    /\ monitor = "none"

Encode ==
    /\ state = "new"
    /\ capturedValue' = sourceValue
    /\ state' = "encoded"
    /\ UNCHANGED <<sourceValue, task, future, monitor>>

MutateSource ==
    /\ state = "encoded"
    /\ sourceValue = 1
    /\ sourceValue' = 2
    /\ UNCHANGED <<capturedValue, state, task, future, monitor>>

BeginDecode ==
    /\ state = "encoded"
    /\ state' = "decoding"
    /\ UNCHANGED <<sourceValue, capturedValue, task, future, monitor>>

Decode ==
    /\ state = "decoding"
    /\ state' = IF DECODE_FAILS THEN "failed" ELSE "decoded"
    /\ task' = IF DECODE_FAILS /\ USE_FIXED THEN "failed" ELSE task
    /\ future' = IF DECODE_FAILS /\ USE_FIXED THEN "failed" ELSE future
    /\ monitor' = IF DECODE_FAILS /\ USE_FIXED THEN "failed" ELSE monitor
    /\ UNCHANGED <<sourceValue, capturedValue>>

Run ==
    /\ state = "decoded"
    /\ state' = "decoded"
    /\ task' = "succeeded"
    /\ future' = "succeeded"
    /\ monitor' = "succeeded"
    /\ UNCHANGED <<sourceValue, capturedValue>>

Next ==
    \/ Encode
    \/ MutateSource
    \/ BeginDecode
    \/ Decode
    \/ Run
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ DECODE_FAILS \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ sourceValue \in 1..2
    /\ capturedValue \in 0..2
    /\ state \in States
    /\ task \in TaskStates
    /\ future \in FutureStates
    /\ monitor \in MonitorStates

SnapshotSafety == state \in {"decoded", "failed"} => capturedValue = 1

DecodeFailureTerminality ==
    state = "failed" =>
        /\ task = "failed"
        /\ future = "failed"
        /\ monitor = "failed"

FutureMonitoringConsistency ==
    future = "succeeded" => task = "succeeded" /\ monitor = "succeeded"

=============================================================================
