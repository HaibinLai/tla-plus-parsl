--------------------------- MODULE ParslRsyncQuoting ---------------------------
EXTENDS Naturals

(***************************************************************************
 * RSyncStaging builds an os.system command by string interpolation.  Paths
 * containing shell whitespace are valid File paths but are not quoted by the
 * current implementation.  The FIXED branch quotes each shell argument.
 *************************************************************************** *)

CONSTANTS PATH_HAS_SPACE, USE_FIXED
VARIABLES state, commandSafe
vars == <<state, commandSafe>>

Init ==
    /\ PATH_HAS_SPACE \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ state = "ready"
    /\ commandSafe = FALSE

BuildCommand ==
    /\ state = "ready"
    /\ state' = IF PATH_HAS_SPACE /\ ~USE_FIXED THEN "ambiguous" ELSE "usable"
    /\ commandSafe' = IF PATH_HAS_SPACE /\ USE_FIXED THEN TRUE ELSE ~PATH_HAS_SPACE

Next ==
    \/ BuildCommand
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in {"ready", "ambiguous", "usable"}
    /\ commandSafe \in BOOLEAN

PathQuotingSafety == state = "ambiguous" => commandSafe

=============================================================================
