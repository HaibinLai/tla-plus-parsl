--------------------------- MODULE ParslCallableDeserializeCache ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Callable deserialization cache aliasing.
 *
 * DillCallableSerializer.deserialize is lru_cached.  Reusing one serializer
 * for the same payload can therefore return the same mutable callable object
 * to multiple tasks.  USE_FIXED models a fresh decode for each payload.
 ***************************************************************************)

CONSTANT USE_FIXED

Phases == {"new", "first_decoded", "mutated", "second_decoded"}
Values == {"none", "original", "mutated"}

VARIABLES phase, cache, firstObject, secondObject
vars == <<phase, cache, firstObject, secondObject>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ phase = "new"
    /\ cache = "none"
    /\ firstObject = "none"
    /\ secondObject = "none"

FirstDecode ==
    /\ phase = "new"
    /\ phase' = "first_decoded"
    /\ firstObject' = "original"
    /\ IF USE_FIXED
          THEN UNCHANGED cache
          ELSE cache' = "original"
    /\ UNCHANGED secondObject

MutateFirst ==
    /\ phase = "first_decoded"
    /\ phase' = "mutated"
    /\ firstObject' = "mutated"
    /\ IF USE_FIXED
          THEN UNCHANGED cache
          ELSE cache' = "mutated"
    /\ UNCHANGED secondObject

SecondDecode ==
    /\ phase = "mutated"
    /\ phase' = "second_decoded"
    /\ secondObject' = IF USE_FIXED THEN "original" ELSE cache
    /\ UNCHANGED <<cache, firstObject>>

Next ==
    \/ FirstDecode
    \/ MutateFirst
    \/ SecondDecode
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ phase \in Phases
    /\ cache \in Values
    /\ firstObject \in Values
    /\ secondObject \in Values

FreshSecondDecode ==
    phase = "second_decoded" => secondObject = "original"

=============================================================================
SPECIFICATION Spec

INVARIANTS
    TypeOK
    FreshSecondDecode
