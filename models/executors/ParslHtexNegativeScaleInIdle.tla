--------------------------- MODULE ParslHtexNegativeScaleInIdle ---------------------------
EXTENDS Naturals

(***************************************************************************
 * HighThroughputExecutor.scale_in has an idle-only branch separate from the
 * generic BlockProvider implementation.  With blocks < 0, its equality
 * check ``len(selected) == blocks`` can never fire, so every eligible idle
 * block is selected.  USE_FIXED rejects the request before selection.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES phase, selected
vars == <<phase, selected>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ phase = "ready"
    /\ selected = 0

ScaleInNegativeIdle ==
    /\ phase = "ready"
    /\ phase' = IF USE_FIXED THEN "rejected" ELSE "scaled"
    /\ selected' = IF USE_FIXED THEN 0 ELSE 3

Next == ScaleInNegativeIdle \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ phase \in {"ready", "rejected", "scaled"}
    /\ selected \in 0..3

NoNegativeIdleSelection ==
    phase = "scaled" => selected = 0

=============================================================================
