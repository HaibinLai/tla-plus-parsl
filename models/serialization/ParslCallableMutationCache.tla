--------------------------- MODULE ParslCallableMutationCache ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Mutable callable objects versus DillCallableSerializer's lru_cache.
 *
 * DillCallableSerializer caches callable serialization by the callable key.
 * A mutable, hashable callable can therefore change its captured state after
 * the first serialization while the cache still returns the old payload.
 * USE_FIXED represents invalidating/recomputing the cache after mutation.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES objectValue, cacheValue, payloadValue, serializations
vars == <<objectValue, cacheValue, payloadValue, serializations>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ objectValue = 1
    /\ cacheValue = 0
    /\ payloadValue = 0
    /\ serializations = 0

FirstSerialize ==
    /\ serializations = 0
    /\ cacheValue' = objectValue
    /\ payloadValue' = objectValue
    /\ serializations' = 1
    /\ UNCHANGED objectValue

MutateCallable ==
    /\ serializations = 1
    /\ objectValue' = 2
    /\ UNCHANGED <<cacheValue, payloadValue, serializations>>

SecondSerialize ==
    /\ serializations = 1
    /\ payloadValue' = IF USE_FIXED THEN objectValue ELSE cacheValue
    /\ cacheValue' = IF USE_FIXED THEN objectValue ELSE cacheValue
    /\ serializations' = 2
    /\ UNCHANGED objectValue

Next ==
    \/ FirstSerialize
    \/ MutateCallable
    \/ SecondSerialize
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ objectValue \in 1..2
    /\ cacheValue \in 0..2
    /\ payloadValue \in 0..2
    /\ serializations \in 0..2

MutationFreshness ==
    serializations = 2 => payloadValue = objectValue

CacheReuseModel ==
    serializations = 2 /\ ~USE_FIXED => payloadValue = cacheValue

=============================================================================
