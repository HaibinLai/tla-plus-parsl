--------------------------- MODULE ParslMemoCheckpointOrder ---------------------------
EXTENDS Naturals
(***************************************************************************
 * BasicMemoizer._load_checkpoints overwrites duplicate hashes while reading
 * checkpoint directories.  get_all_checkpoints orders UUID run directory
 * names lexically, which is not execution chronology.  The model compares
 * the load order with the intended old->new order.
 *************************************************************************** *)

CONSTANTS FIRST_LOAD, SECOND_LOAD, USE_FIXED

VARIABLES index, loaded, chronology

Init ==
    /\ FIRST_LOAD \in {"old", "new"}
    /\ SECOND_LOAD \in {"old", "new"}
    /\ FIRST_LOAD # SECOND_LOAD
    /\ chronology = <<"old", "new">>
    /\ index = 1
    /\ loaded = "none"

LoadNext ==
    /\ index <= 2
    /\ loaded' = IF index = 1 THEN FIRST_LOAD ELSE SECOND_LOAD
    /\ index' = index + 1
    /\ UNCHANGED chronology

Done ==
    /\ index > 2
    /\ UNCHANGED <<index, loaded, chronology>>

Next == LoadNext \/ Done
vars == <<index, loaded, chronology>>
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ index \in Nat
    /\ loaded \in {"none", "old", "new"}
    /\ chronology = <<"old", "new">>

LatestCheckpointWins ==
    index > 2 => loaded = "new"

=============================================================================
