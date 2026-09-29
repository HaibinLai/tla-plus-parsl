--------------------------- MODULE ParslSerializationEmptyRegistry ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Empty serializer-registry handling in parsl.serialize.facade.serialize.
 *
 * The current loop assigns ``result`` only after visiting one serializer.
 * With an empty registry it reaches the final test with an unbound local,
 * leaking an implementation-level UnboundLocalError.  The fixed branch
 * rejects the request with an explicit serializer-unavailable outcome.
 ***************************************************************************)

CONSTANT USE_FIXED
States == {"ready", "serialized", "unbound_error", "rejected"}

VARIABLES state, registrySize
vars == <<state, registrySize>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ state = "ready"
    /\ registrySize = 0

Serialize ==
    /\ state = "ready"
    /\ registrySize = 0
    /\ state' = IF USE_FIXED THEN "rejected" ELSE "unbound_error"
    /\ UNCHANGED registrySize

SerializeWithMethod ==
    /\ state = "ready"
    /\ registrySize > 0
    /\ state' = "serialized"
    /\ UNCHANGED registrySize

Next ==
    \/ Serialize
    \/ SerializeWithMethod
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in States
    /\ registrySize \in Nat

ExplicitFailureSafety ==
    state = "unbound_error" => USE_FIXED

=============================================================================
