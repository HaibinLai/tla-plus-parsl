--------------------------- MODULE ParslLastCheckpointUUID ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Parsl DFK run directories currently use UUIDs.  get_last_checkpoint,
 * however, filters candidates with isdigit() before selecting a directory.
 * The current branch therefore misses a valid UUID-named checkpoint.
 *************************************************************************** *)

CONSTANTS RUN_KIND, USE_FIXED

VARIABLES scanned, selected

Init ==
    /\ RUN_KIND \in {"uuid", "numeric"}
    /\ USE_FIXED \in BOOLEAN
    /\ scanned = FALSE
    /\ selected = "none"

Scan ==
    /\ ~scanned
    /\ scanned' = TRUE
    /\ selected' = IF USE_FIXED \/ RUN_KIND = "numeric" THEN "checkpoint" ELSE "none"

Done ==
    /\ scanned
    /\ UNCHANGED <<scanned, selected>>

Next == Scan \/ Done
vars == <<scanned, selected>>
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ scanned \in BOOLEAN
    /\ selected \in {"none", "checkpoint"}

UUIDCheckpointRecovery ==
    scanned /\ RUN_KIND = "uuid" => selected = "checkpoint"

=============================================================================
