--------------------------- MODULE ParslFluxSerializationErrorName ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Flux submit uses the same callable-name error path as HTEX.
 *
 * A TypeError from pack_apply_message followed by func.__name__ can mask the
 * original serialization failure for callable instances.  The fixed branch
 * preserves an explicit SerializationError outcome.
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
