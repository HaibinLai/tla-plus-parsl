--------------------------- MODULE ParslFunctionGlobalDefaultFutureRetry ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Callable global/default epochs composed with a task envelope, Future, and
 * physical retry.  Function code and its default arguments are serialized as
 * separate roots.  A source mutation between those operations creates a
 * mixed-epoch callable in the Current branch; the Fixed branch fails that
 * attempt and retries from one coherent snapshot.
 ***************************************************************************)

CONSTANT USE_FIXED

TaskStates == {"pending", "decoded", "failed", "succeeded"}
FutureStates == {"pending", "failed", "succeeded"}
MonitorStates == {"none", "failed", "succeeded"}

VARIABLES sourceEpoch, sourceGlobal, sourceDefault, functionEpoch,
          defaultEpoch, capturedGlobal, capturedDefault, functionEncoded,
          defaultEncoded, task, future, monitor, attempt, result
vars == <<sourceEpoch, sourceGlobal, sourceDefault, functionEpoch,
           defaultEpoch, capturedGlobal, capturedDefault, functionEncoded,
           defaultEncoded, task, future, monitor, attempt, result>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ sourceEpoch = 0
    /\ sourceGlobal = 1
    /\ sourceDefault = 2
    /\ functionEpoch = 0
    /\ defaultEpoch = 0
    /\ capturedGlobal = 0
    /\ capturedDefault = 0
    /\ functionEncoded = FALSE
    /\ defaultEncoded = FALSE
    /\ task = "pending"
    /\ future = "pending"
    /\ monitor = "none"
    /\ attempt = 0
    /\ result = 0

EncodeFunction ==
    /\ ~functionEncoded
    /\ functionEncoded' = TRUE
    /\ functionEpoch' = sourceEpoch
    /\ capturedGlobal' = sourceGlobal
    /\ UNCHANGED <<sourceEpoch, sourceGlobal, sourceDefault, defaultEpoch,
                    capturedDefault, defaultEncoded, task, future, monitor,
                    attempt, result>>

EncodeDefault ==
    /\ ~defaultEncoded
    /\ defaultEncoded' = TRUE
    /\ defaultEpoch' = sourceEpoch
    /\ capturedDefault' = sourceDefault
    /\ UNCHANGED <<sourceEpoch, sourceGlobal, sourceDefault, functionEpoch,
                    capturedGlobal, functionEncoded, task, future, monitor,
                    attempt, result>>

MutateSource ==
    /\ sourceEpoch = 0
    /\ functionEncoded # defaultEncoded
    /\ sourceEpoch' = 1
    /\ sourceGlobal' = 10
    /\ sourceDefault' = 20
    /\ UNCHANGED <<functionEpoch, defaultEpoch, capturedGlobal, capturedDefault,
                    functionEncoded, defaultEncoded, task, future, monitor,
                    attempt, result>>

DecodeConsistent ==
    /\ task = "pending"
    /\ functionEncoded /\ defaultEncoded
    /\ functionEpoch = defaultEpoch
    /\ task' = "decoded"
    /\ result' = capturedGlobal + capturedDefault + 3
    /\ UNCHANGED <<sourceEpoch, sourceGlobal, sourceDefault, functionEpoch,
                    defaultEpoch, capturedGlobal, capturedDefault,
                    functionEncoded, defaultEncoded, future, monitor,
                    attempt>>

DecodeMixed ==
    /\ task = "pending"
    /\ functionEncoded /\ defaultEncoded
    /\ functionEpoch # defaultEpoch
    /\ IF USE_FIXED
          THEN /\ task' = "failed"
               /\ future' = "failed"
               /\ monitor' = "failed"
               /\ UNCHANGED result
          ELSE /\ task' = "decoded"
               /\ result' = sourceGlobal + capturedDefault + 3
               /\ UNCHANGED <<future, monitor>>
    /\ UNCHANGED <<sourceEpoch, sourceGlobal, sourceDefault, functionEpoch,
                    defaultEpoch, capturedGlobal, capturedDefault,
                    functionEncoded, defaultEncoded, attempt>>

Execute ==
    /\ task = "decoded"
    /\ task' = "succeeded"
    /\ future' = "succeeded"
    /\ monitor' = "succeeded"
    /\ UNCHANGED <<sourceEpoch, sourceGlobal, sourceDefault, functionEpoch,
                    defaultEpoch, capturedGlobal, capturedDefault,
                    functionEncoded, defaultEncoded, attempt, result>>

RetryFailed ==
    /\ task = "failed"
    /\ attempt = 0
    /\ attempt' = 1
    /\ task' = "pending"
    /\ future' = "pending"
    /\ monitor' = "none"
    /\ functionEncoded' = FALSE
    /\ defaultEncoded' = FALSE
    /\ UNCHANGED <<sourceEpoch, sourceGlobal, sourceDefault, functionEpoch,
                    defaultEpoch, capturedGlobal, capturedDefault, result>>

Next ==
    \/ EncodeFunction
    \/ EncodeDefault
    \/ MutateSource
    \/ DecodeConsistent
    \/ DecodeMixed
    \/ Execute
    \/ RetryFailed
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ sourceEpoch \in 0..1
    /\ sourceGlobal \in {1, 10}
    /\ sourceDefault \in {2, 20}
    /\ functionEpoch \in 0..1
    /\ defaultEpoch \in 0..1
    /\ capturedGlobal \in 0..10
    /\ capturedDefault \in 0..20
    /\ functionEncoded \in BOOLEAN
    /\ defaultEncoded \in BOOLEAN
    /\ task \in TaskStates
    /\ future \in FutureStates
    /\ monitor \in MonitorStates
    /\ attempt \in 0..1
    /\ result \in 0..40

SnapshotResultSafety ==
    future = "succeeded" => result = capturedGlobal + capturedDefault + 3

FailureVisibility == future = "failed" => monitor = "failed"

RetryBound == attempt \in 0..1

=============================================================================
