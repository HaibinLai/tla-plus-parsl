--------------------------- MODULE ParslCallableSerializerCache ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Callable-object serialization and the DillCallableSerializer cache.
 *
 * Parsl routes callable objects to DillCallableSerializer.  Its serialize
 * method is wrapped by functools.lru_cache, so an otherwise serializable
 * callable whose __hash__ is disabled fails while computing the cache key.
 * USE_FIXED models bypassing the cache for unhashable callable objects.
 ***************************************************************************)

CONSTANT USE_FIXED
States == {"new", "serialized", "failed"}

VARIABLES callableObject, hashable, state, dillReachable
vars == <<callableObject, hashable, state, dillReachable>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ callableObject = TRUE
    /\ hashable = FALSE
    /\ state = "new"
    /\ dillReachable = FALSE

SerializeCallable ==
    /\ callableObject
    /\ state = "new"
    /\ IF hashable \/ USE_FIXED
          THEN /\ state' = "serialized"
               /\ dillReachable' = TRUE
          ELSE /\ state' = "failed"
               /\ dillReachable' = FALSE
    /\ UNCHANGED <<callableObject, hashable>>

Next ==
    \/ SerializeCallable
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ callableObject \in BOOLEAN
    /\ hashable \in BOOLEAN
    /\ state \in States
    /\ dillReachable \in BOOLEAN

CallableSerializationSafety ==
    state = "serialized" => dillReachable

UnhashableCallableSafety ==
    hashable = FALSE => state # "failed"

=============================================================================
