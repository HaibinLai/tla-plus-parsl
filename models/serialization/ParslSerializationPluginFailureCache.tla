--------------------------- MODULE ParslSerializationPluginFailureCache ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Dynamic deserializer cache after a plugin decode failure.
 *
 * facade.deserialize stores a dynamically loaded plugin in
 * additional_methods_for_deserialization before invoking deserialize().  A
 * failing plugin therefore remains cached.  USE_FIXED models evicting the
 * plugin when decode raises so a later request can reload it.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES phase, cachePresent, decodeAttempts
vars == <<phase, cachePresent, decodeAttempts>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ phase = "wire"
    /\ cachePresent = FALSE
    /\ decodeAttempts = 0

LoadAndFail ==
    /\ phase = "wire"
    /\ phase' = "failed"
    /\ cachePresent' = IF USE_FIXED THEN FALSE ELSE TRUE
    /\ decodeAttempts' = decodeAttempts + 1

ReloadAfterFailure ==
    /\ phase = "failed"
    /\ ~cachePresent
    /\ phase' = "decoded"
    /\ cachePresent' = TRUE
    /\ decodeAttempts' = decodeAttempts + 1

Next ==
    \/ LoadAndFail
    \/ ReloadAfterFailure
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ phase \in {"wire", "failed", "decoded"}
    /\ cachePresent \in BOOLEAN
    /\ decodeAttempts \in 0..2

FailureEvictionSafety ==
    phase = "failed" => ~cachePresent

=============================================================================
