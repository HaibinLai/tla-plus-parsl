--------------------------- MODULE ParslHtexSerializationFailure ---------------------------
EXTENDS Naturals

(***************************************************************************
 * HTEX submit serialization failure normalization.
 *
 * HighThroughputExecutor.submit catches TypeError from pack_apply_message and
 * converts it to Parsl's SerializationError.  The serializer facade can raise
 * other exception classes too.  The fixed branch normalizes every serializer
 * failure before it escapes submit.
 ***************************************************************************)

CONSTANT FAIL_KIND, USE_FIXED

VARIABLES phase, outcome
vars == <<phase, outcome>>

Init ==
    /\ FAIL_KIND \in {"type", "value"}
    /\ USE_FIXED \in BOOLEAN
    /\ phase = "serializing"
    /\ outcome = "none"

SerializeFailure ==
    /\ phase = "serializing"
    /\ phase' = "failed"
    /\ outcome' = IF USE_FIXED \/ FAIL_KIND = "type"
                      THEN "SerializationError"
                      ELSE "raw"

Next == SerializeFailure \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ FAIL_KIND \in {"type", "value"}
    /\ USE_FIXED \in BOOLEAN
    /\ phase \in {"serializing", "failed"}
    /\ outcome \in {"none", "SerializationError", "raw"}

FailureNormalization == phase = "failed" => outcome = "SerializationError"

=============================================================================
SPECIFICATION Spec

INVARIANTS
    TypeOK
    FailureNormalization
