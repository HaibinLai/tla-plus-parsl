--------------------------- MODULE ParslLocalSubmitPidShape ---------------------------
EXTENDS Naturals

(***************************************************************************
 * LocalProvider submit response parsing.
 *
 * A successful launcher command is expected to print ``PID:<integer>``.
 * The current provider converts the suffix with int() without validating
 * the response shape, exposing ValueError for a malformed but successful
 * launcher response.  USE_FIXED represents controlled rejection.
 *************************************************************************** *)

CONSTANT USE_FIXED

States == {"launching", "registered", "failed", "crashed"}

VARIABLES state
vars == <<state>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ state = "launching"

ParsePid ==
    /\ state = "launching"
    /\ state' = IF USE_FIXED THEN "failed" ELSE "crashed"

RegisterValidPid ==
    /\ state = "launching"
    /\ state' = "registered"

Next ==
    \/ ParsePid
    \/ RegisterValidPid
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK == state \in States

NoRawParseCrash == state # "crashed"

TerminalStability == state \in {"registered", "failed"} => state' = state

=============================================================================
