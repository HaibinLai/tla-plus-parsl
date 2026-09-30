--------------------------- MODULE ParslHtexSerializationErrorName ---------------------------
EXTENDS Naturals

(***************************************************************************
 * HTEX serialization error reporting for callable objects.
 *
 * HighThroughputExecutor.submit catches a TypeError and constructs
 * SerializationError(func.__name__).  Callable instances may implement
 * __call__ without defining __name__, so the error-reporting path can raise
 * AttributeError and hide the original serialization failure.  The fixed
 * branch uses a safe callable description.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES phase, outcome
vars == <<phase, outcome>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ phase = "serializing"
    /\ outcome = "none"

SerializationTypeError ==
    /\ phase = "serializing"
    /\ phase' = "failed"
    /\ outcome' = IF USE_FIXED THEN "SerializationError" ELSE "AttributeError"

Next == SerializationTypeError \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ phase \in {"serializing", "failed"}
    /\ outcome \in {"none", "SerializationError", "AttributeError"}

CallableFailureSafety == phase = "failed" => outcome = "SerializationError"

=============================================================================
