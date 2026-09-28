--------------------------- MODULE ParslSerializationPluginCache ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Dynamic deserializer plugin caching in parsl/serialize/facade.py.
 *
 * An unknown header is imported and instantiated once.  Successful lookup is
 * placed in additional_methods_for_deserialization, so a later payload with
 * the same header reuses the cached plugin instead of importing again.
 ***************************************************************************)

CONSTANT LOAD_OK
States == {"wire", "loaded", "decoded", "failed"}

VARIABLES state, importCount, cachePresent, decodeCount
vars == <<state, importCount, cachePresent, decodeCount>>

Init ==
    /\ LOAD_OK \in BOOLEAN
    /\ state = "wire"
    /\ importCount = 0
    /\ cachePresent = FALSE
    /\ decodeCount = 0

FirstDeserialize ==
    /\ state = "wire"
    /\ IF LOAD_OK
          THEN /\ state' = "loaded"
               /\ importCount' = 1
               /\ cachePresent' = TRUE
               /\ decodeCount' = 1
          ELSE /\ state' = "failed"
               /\ UNCHANGED <<importCount, cachePresent, decodeCount>>

SecondDeserialize ==
    /\ state = "loaded"
    /\ cachePresent
    /\ state' = "decoded"
    /\ decodeCount' = 2
    /\ UNCHANGED <<importCount, cachePresent>>

Next ==
    \/ FirstDeserialize
    \/ SecondDeserialize
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ LOAD_OK \in BOOLEAN
    /\ state \in States
    /\ importCount \in 0..1
    /\ cachePresent \in BOOLEAN
    /\ decodeCount \in 0..2

CacheSafety ==
    state = "decoded" =>
        /\ LOAD_OK
        /\ cachePresent
        /\ importCount = 1
        /\ decodeCount = 2

=============================================================================
