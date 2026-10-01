--------------------------- MODULE ParslFunctionGlobalDefaultSnapshot ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Callable global/default snapshot consistency.
 *
 * A function payload carries both a referenced global object and its default
 * argument values.  They must be decoded from one serialization epoch.  The
 * Current branch permits a mixed-epoch callable; the Fixed branch rejects the
 * inconsistent payload before execution.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES sourceEpoch, sourceGlobal, sourceDefault, functionEpoch,
          defaultEpoch, capturedGlobal, capturedDefault, functionEncoded,
          defaultEncoded, state, result

vars == <<sourceEpoch, sourceGlobal, sourceDefault, functionEpoch,
          defaultEpoch, capturedGlobal, capturedDefault, functionEncoded,
          defaultEncoded, state, result>>

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
    /\ state = "pending"
    /\ result = 0

EncodeFunction ==
    /\ ~functionEncoded
    /\ functionEncoded' = TRUE
    /\ functionEpoch' = sourceEpoch
    /\ capturedGlobal' = sourceGlobal
    /\ UNCHANGED <<sourceEpoch, sourceGlobal, sourceDefault, defaultEpoch,
                    capturedDefault, defaultEncoded, state, result>>

EncodeDefault ==
    /\ ~defaultEncoded
    /\ defaultEncoded' = TRUE
    /\ defaultEpoch' = sourceEpoch
    /\ capturedDefault' = sourceDefault
    /\ UNCHANGED <<sourceEpoch, sourceGlobal, sourceDefault, functionEpoch,
                    capturedGlobal, functionEncoded, state, result>>

MutateSource ==
    /\ sourceEpoch < 1
    /\ functionEncoded # defaultEncoded
    /\ sourceEpoch' = 1
    /\ sourceGlobal' = 10
    /\ sourceDefault' = 20
    /\ UNCHANGED <<functionEpoch, defaultEpoch, capturedGlobal, capturedDefault,
                    functionEncoded, defaultEncoded, state, result>>

DecodeConsistent ==
    /\ functionEncoded
    /\ defaultEncoded
    /\ functionEpoch = defaultEpoch
    /\ state' = "decoded"
    /\ result' = capturedGlobal + capturedDefault + 3
    /\ UNCHANGED <<sourceEpoch, sourceGlobal, sourceDefault, functionEpoch,
                    defaultEpoch, capturedGlobal, capturedDefault,
                    functionEncoded, defaultEncoded>>

DecodeMixedFixed ==
    /\ USE_FIXED
    /\ functionEncoded
    /\ defaultEncoded
    /\ functionEpoch # defaultEpoch
    /\ state' = "failed"
    /\ UNCHANGED <<sourceEpoch, sourceGlobal, sourceDefault, functionEpoch,
                    defaultEpoch, capturedGlobal, capturedDefault,
                    functionEncoded, defaultEncoded, result>>

DecodeMixedCurrent ==
    /\ ~USE_FIXED
    /\ functionEncoded
    /\ defaultEncoded
    /\ functionEpoch # defaultEpoch
    /\ state' = "decoded"
    /\ result' = sourceGlobal + capturedDefault + 3
    /\ UNCHANGED <<sourceEpoch, sourceGlobal, sourceDefault, functionEpoch,
                    defaultEpoch, capturedGlobal, capturedDefault,
                    functionEncoded, defaultEncoded>>

Next ==
    \/ EncodeFunction
    \/ EncodeDefault
    \/ MutateSource
    \/ DecodeConsistent
    \/ DecodeMixedFixed
    \/ DecodeMixedCurrent
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
    /\ state \in {"pending", "decoded", "failed"}
    /\ result \in 0..40

SnapshotConsistency == state = "decoded" => functionEpoch = defaultEpoch
SnapshotResultSafety ==
    (USE_FIXED /\ state = "decoded")
        => result = capturedGlobal + capturedDefault + 3
FailureTerminality == state = "failed" => state = "failed"

=============================================================================
