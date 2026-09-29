--------------------------- MODULE ParslCallableEqualCache ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Callable serializer cache key semantics.
 *
 * DillCallableSerializer.serialize is lru_cache-wrapped.  Python's cache key
 * uses equality and hash, so two distinct callable objects with equal keys
 * can reuse the first object's bytes even when their captured contents differ.
 * The fixed branch keys by object identity/content snapshot instead.
 ***************************************************************************)

CONSTANT USE_FIXED

Phases == {"new", "first", "second"}
Contents == {"A", "B"}

VARIABLES phase, cacheValue, observed
vars == <<phase, cacheValue, observed>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ phase = "new"
    /\ cacheValue = "none"
    /\ observed = "none"

SerializeFirst ==
    /\ phase = "new"
    /\ phase' = "first"
    /\ cacheValue' = "A"
    /\ UNCHANGED observed

SerializeEqualSecond ==
    /\ phase = "first"
    /\ phase' = "second"
    /\ observed' = IF USE_FIXED THEN "B" ELSE cacheValue
    /\ UNCHANGED cacheValue

Next ==
    \/ SerializeFirst
    \/ SerializeEqualSecond
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ phase \in Phases
    /\ cacheValue \in Contents \cup {"none"}
    /\ observed \in Contents \cup {"none"}

EqualCallableFreshness ==
    phase = "second" => observed = "B"

=============================================================================
