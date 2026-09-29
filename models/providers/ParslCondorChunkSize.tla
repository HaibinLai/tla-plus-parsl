--------------------------- MODULE ParslCondorChunkSize ---------------------------
EXTENDS Integers

(***************************************************************************
 * Condor provider command chunk-size admission.
 *
 * ``cmd_chunk_size`` controls scheduler command batching.  The current
 * ``_chunker`` helper silently treats zero or negative sizes as one unbounded
 * chunk; USE_FIXED models rejecting non-positive values at construction.
 *************************************************************************** *)

CONSTANTS SIZE_KIND, USE_FIXED
Kinds == {"negative", "zero", "positive"}
States == {"unvalidated", "accepted", "rejected"}

VARIABLES state
vars == <<state>>

Init ==
    /\ SIZE_KIND \in Kinds
    /\ USE_FIXED \in BOOLEAN
    /\ state = "unvalidated"

Validate ==
    /\ state = "unvalidated"
    /\ state' = IF (SIZE_KIND = "negative" \/ SIZE_KIND = "zero") /\ USE_FIXED
                   THEN "rejected" ELSE "accepted"

Next ==
    \/ Validate
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ SIZE_KIND \in Kinds
    /\ USE_FIXED \in BOOLEAN
    /\ state \in States

ChunkSizeSafety ==
    state = "accepted" => SIZE_KIND = "positive"

=============================================================================
