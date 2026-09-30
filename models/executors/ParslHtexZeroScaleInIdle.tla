--------------------------- MODULE ParslHtexZeroScaleInIdle ---------------------------
EXTENDS Naturals

(***************************************************************************
 * HTEX idle-only scale-in checks the requested count after appending a
 * candidate.  For blocks = 0, the equality can never hold after the first
 * append, so every eligible idle block is selected.  USE_FIXED handles zero
 * as a no-op before scanning managers.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES phase, selected
vars == <<phase, selected>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ phase = "ready"
    /\ selected = 0

ScaleInZeroIdle ==
    /\ phase = "ready"
    /\ phase' = IF USE_FIXED THEN "complete" ELSE "scaled"
    /\ selected' = IF USE_FIXED THEN 0 ELSE 3

Next == ScaleInZeroIdle \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ phase \in {"ready", "complete", "scaled"}
    /\ selected \in 0..3

ZeroRequestSafety ==
    phase = "scaled" => selected = 0

=============================================================================
