-------------------- MODULE ParslRadicalSerializationFailure --------------------
EXTENDS Naturals

(***************************************************************************
 * Radical-Pilot serialization failure normalization.
 *
 * RadicalPilotExecutor._pack_and_apply_message translates only TypeError from
 * pack_apply_message into SerializationError.  A different serializer
 * exception can escape the executor boundary.  The fixed branch normalizes
 * every serializer failure before returning to the caller.
 *************************************************************************** *)

CONSTANTS USE_FIXED, NON_TYPE_ERROR

States == {"ready", "serialized", "normalized", "raw_error"}

VARIABLE state
vars == <<state>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ NON_TYPE_ERROR \in BOOLEAN
    /\ state = "ready"

Pack ==
    /\ state = "ready"
    /\ IF NON_TYPE_ERROR
          THEN IF USE_FIXED THEN state' = "normalized" ELSE state' = "raw_error"
          ELSE state' = "serialized"

Next == Pack \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in States
    /\ NON_TYPE_ERROR \in BOOLEAN

FailureNormalization == NON_TYPE_ERROR => state # "raw_error"

=============================================================================
