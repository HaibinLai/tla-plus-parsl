--------------------------- MODULE ParslMemoDictOrdering ---------------------------
EXTENDS Naturals

(***************************************************************************
 * id_for_memo_dict currently calls sorted(dict) directly.  Python permits
 * dictionaries with heterogeneous keys, but such keys are not orderable in
 * Python 3.  The FIXED branch uses a canonical type/value ordering instead.
 *************************************************************************** *)

CONSTANTS MIXED_KEYS, USE_FIXED
VARIABLES state, keyReady
vars == <<state, keyReady>>

Init ==
    /\ MIXED_KEYS \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ state = "ready"
    /\ keyReady = FALSE

HashDict ==
    /\ state = "ready"
    /\ state' = IF MIXED_KEYS /\ ~USE_FIXED THEN "error" ELSE "hashed"
    /\ keyReady' = IF MIXED_KEYS /\ ~USE_FIXED THEN FALSE ELSE TRUE

Next ==
    \/ HashDict
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in {"ready", "hashed", "error"}
    /\ keyReady \in BOOLEAN

MixedDictHashSafety == state = "error" => ~MIXED_KEYS

=============================================================================
