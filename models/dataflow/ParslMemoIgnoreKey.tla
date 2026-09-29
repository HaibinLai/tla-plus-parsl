--------------------------- MODULE ParslMemoIgnoreKey ---------------------------
EXTENDS Naturals, FiniteSets

(***************************************************************************
 * Memoization ignore-list validation.
 *
 * BasicMemoizer.make_hash removes every name in ignore_for_cache from the
 * keyword map.  An unknown name currently reaches a raw KeyError.  The fixed
 * branch validates the names before mutating the filtered keyword map and
 * reports a controlled rejection.
 ***************************************************************************)

CONSTANT USE_FIXED

Phases == {"ready", "hashed", "rejected", "raw_error"}
KnownKeys == {"x", "outputs"}
IgnoreKeys == {"x", "unknown"}

VARIABLES phase, filteredKeys
vars == <<phase, filteredKeys>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ phase = "ready"
    /\ filteredKeys = KnownKeys

BuildHash ==
    /\ phase = "ready"
    /\ IgnoreKeys \subseteq KnownKeys
    /\ phase' = "hashed"
    /\ filteredKeys' = KnownKeys \ IgnoreKeys

RejectUnknownFixed ==
    /\ USE_FIXED
    /\ phase = "ready"
    /\ ~(IgnoreKeys \subseteq KnownKeys)
    /\ phase' = "rejected"
    /\ UNCHANGED filteredKeys

RawUnknownCurrent ==
    /\ ~USE_FIXED
    /\ phase = "ready"
    /\ ~(IgnoreKeys \subseteq KnownKeys)
    /\ phase' = "raw_error"
    /\ UNCHANGED filteredKeys

Next ==
    \/ BuildHash
    \/ RejectUnknownFixed
    \/ RawUnknownCurrent
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ phase \in Phases
    /\ filteredKeys \subseteq KnownKeys

NoRawIgnoreKeyError == phase # "raw_error"

=============================================================================
