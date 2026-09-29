--------------------------- MODULE ParslFunctionObjectContents ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Minimal Python callable/object-content snapshot.
 *
 * A task carries a callable closure and its argument object through separate
 * serialization operations.  The wire payload is a snapshot: later mutation
 * of the submitting process must not change what the worker executes.
 ***************************************************************************)

VARIABLES sourceValue, capturedFunctionValue, capturedArgumentValue,
          functionEncoded, argumentEncoded, decoded, result

vars == <<sourceValue, capturedFunctionValue, capturedArgumentValue,
          functionEncoded, argumentEncoded, decoded, result>>

Init ==
    /\ sourceValue = 1
    /\ capturedFunctionValue = 0
    /\ capturedArgumentValue = 0
    /\ functionEncoded = FALSE
    /\ argumentEncoded = FALSE
    /\ decoded = FALSE
    /\ result = 0

SerializeFunction ==
    /\ ~functionEncoded
    /\ functionEncoded' = TRUE
    /\ capturedFunctionValue' = sourceValue
    /\ UNCHANGED <<sourceValue, capturedArgumentValue, argumentEncoded,
                    decoded, result>>

SerializeArgument ==
    /\ ~argumentEncoded
    /\ argumentEncoded' = TRUE
    /\ capturedArgumentValue' = sourceValue
    /\ UNCHANGED <<sourceValue, capturedFunctionValue, functionEncoded,
                    decoded, result>>

MutateSource ==
    /\ sourceValue = 1
    /\ functionEncoded
    /\ argumentEncoded
    /\ sourceValue' = 2
    /\ UNCHANGED <<capturedFunctionValue, capturedArgumentValue,
                    functionEncoded, argumentEncoded, decoded, result>>

DecodeAndRun ==
    /\ functionEncoded
    /\ argumentEncoded
    /\ ~decoded
    /\ decoded' = TRUE
    /\ result' = capturedFunctionValue + capturedArgumentValue
    /\ UNCHANGED <<sourceValue, capturedFunctionValue, capturedArgumentValue,
                    functionEncoded, argumentEncoded>>

Next ==
    \/ SerializeFunction
    \/ SerializeArgument
    \/ MutateSource
    \/ DecodeAndRun
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ sourceValue \in 1..2
    /\ capturedFunctionValue \in 0..2
    /\ capturedArgumentValue \in 0..2
    /\ functionEncoded \in BOOLEAN
    /\ argumentEncoded \in BOOLEAN
    /\ decoded \in BOOLEAN
    /\ result \in 0..4

SnapshotSafety ==
    decoded => result = capturedFunctionValue + capturedArgumentValue

MutationIsolation ==
    decoded /\ sourceValue = 2 =>
        capturedFunctionValue = 1 /\ capturedArgumentValue = 1

=============================================================================
