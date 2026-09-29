--------------------------- MODULE ParslCallableArgumentAlias ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Alias identity across a serialized callable and its arguments.
 *
 * pack_apply_message serializes the callable and argument tuple separately.
 * If a closure captures the same mutable object that is also passed as an
 * argument, the current wire format reconstructs two equal but non-identical
 * objects.  A bundled graph (the fixed branch) preserves the alias.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES phase, callableObject, argumentObject, observedAlias

vars == <<phase, callableObject, argumentObject, observedAlias>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ phase = "new"
    /\ callableObject = "source-shared"
    /\ argumentObject = "source-shared"
    /\ observedAlias = FALSE

Serialize ==
    /\ phase = "new"
    /\ phase' = "serialized"
    /\ UNCHANGED <<callableObject, argumentObject, observedAlias>>

Decode ==
    /\ phase = "serialized"
    /\ phase' = "decoded"
    /\ observedAlias' = USE_FIXED
    /\ UNCHANGED <<callableObject, argumentObject>>

Next ==
    \/ Serialize
    \/ Decode
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ phase \in {"new", "serialized", "decoded"}
    /\ callableObject = "source-shared"
    /\ argumentObject = "source-shared"
    /\ observedAlias \in BOOLEAN

AliasSafety ==
    phase = "decoded" => observedAlias

FixedAliasSafety ==
    USE_FIXED => (phase = "decoded" => observedAlias)

=============================================================================
