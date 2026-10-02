-------------------- MODULE ParslFluxSerializationFailure --------------------
EXTENDS Naturals

(***************************************************************************
 * Flux submit-side serializer failure normalization.
 *
 * FluxExecutor.submit currently translates only TypeError from
 * pack_apply_message.  A different serializer exception escapes raw; the
 * fixed branch turns every serializer failure into SerializationError.
 ***************************************************************************)

CONSTANT USE_FIXED

States == {"ready", "serialized", "normalized", "raw_error"}

VARIABLE state
vars == <<state>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ state = "ready"

PackValueError ==
    /\ state = "ready"
    /\ state' = IF USE_FIXED THEN "normalized" ELSE "raw_error"

Next == PackValueError \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in States
    /\ USE_FIXED \in BOOLEAN

FailureNormalization == state = "raw_error" => FALSE

=============================================================================
