--------------------------- MODULE ParslWorkQueueFileCacheIdentity ---------------------------
EXTENDS Naturals, FiniteSets

(***************************************************************************
 * Work Queue file-cache identity.
 *
 * WorkQueueExecutor._register_file documents a filepath-based cache, but
 * the current implementation stores File objects in registered_files.  Two
 * distinct File objects for the same path therefore miss the second-use
 * cache hint.  The fixed branch keys the registry by filepath.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES uses, registered, cacheHint
vars == <<uses, registered, cacheHint>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ uses = 0
    /\ registered = {}
    /\ cacheHint = FALSE

RegisterSamePath ==
    /\ uses < 2
    /\ uses' = uses + 1
    /\ cacheHint' = IF USE_FIXED
                       THEN "input.dat" \in registered
                       ELSE FALSE
    /\ registered' = IF USE_FIXED
                       THEN registered \cup {"input.dat"}
                       ELSE registered \cup {IF uses = 0 THEN "obj-1" ELSE "obj-2"}

Next ==
    \/ RegisterSamePath
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ uses \in 0..2
    /\ registered \subseteq {"input.dat", "obj-1", "obj-2"}
    /\ cacheHint \in BOOLEAN

CacheContract ==
    uses = 2 => cacheHint

=============================================================================
