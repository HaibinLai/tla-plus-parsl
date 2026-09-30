--------------------------- MODULE ParslZipPathFirstMatch ---------------------------
EXTENDS Naturals

(***************************************************************************
 * zip_path_split uses str.find(".zip/").  A valid path can contain a parent
 * directory ending in .zip before the actual archive, so the first match is
 * not necessarily the archive boundary.  The current branch chooses the
 * first match; the FIXED branch chooses the final .zip/ separator.
 ***************************************************************************)

CONSTANTS SEPARATOR_COUNT, FIXED

Phases == {"idle", "split", "rejected"}
VARIABLES phase, selected
vars == <<phase, selected>>

Init ==
    /\ SEPARATOR_COUNT \in 1..2
    /\ FIXED \in BOOLEAN
    /\ phase = "idle"
    /\ selected = 0

SplitPath ==
    /\ phase = "idle"
    /\ IF FIXED /\ SEPARATOR_COUNT > 1
          THEN /\ selected' = SEPARATOR_COUNT
               /\ phase' = "split"
          ELSE /\ selected' = 1
               /\ phase' = "split"

Next ==
    \/ SplitPath
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ SEPARATOR_COUNT \in 1..2
    /\ FIXED \in BOOLEAN
    /\ phase \in Phases
    /\ selected \in 0..2

FinalSeparatorSafety ==
    phase = "split" => FIXED \/ SEPARATOR_COUNT = 1 \/ selected = SEPARATOR_COUNT

=============================================================================
