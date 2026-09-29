--------------------------- MODULE ParslGlobusEndpointPath ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Globus endpoint path validation.
 *
 * GlobusStaging._get_globus_endpoint requires an executor working directory.
 * It also intends to accept local_path equal to, or below, that directory.
 * The current implementation compares local_path with common_path directly,
 * so a valid child path is rejected.  USE_FIXED models the intended guard.
 *************************************************************************** *)

CONSTANTS WORKING_DIR_PRESENT, RELATION, USE_FIXED

Relations == {"equal", "subpath", "outside"}
VARIABLES state, accepted
vars == <<state, accepted>>

Init ==
    /\ WORKING_DIR_PRESENT \in BOOLEAN
    /\ RELATION \in Relations
    /\ USE_FIXED \in BOOLEAN
    /\ state = "unresolved"
    /\ accepted = FALSE

ResolveEndpoint ==
    /\ state = "unresolved"
    /\ IF ~WORKING_DIR_PRESENT \/ RELATION = "outside"
          THEN /\ state' = "rejected"
               /\ accepted' = FALSE
          ELSE IF RELATION = "subpath" /\ ~USE_FIXED
               THEN /\ state' = "crashed"
                    /\ accepted' = FALSE
               ELSE /\ state' = "accepted"
                    /\ accepted' = TRUE

Next ==
    \/ ResolveEndpoint
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in {"unresolved", "accepted", "rejected", "crashed"}
    /\ accepted \in BOOLEAN

AllowedPathSafety ==
    (WORKING_DIR_PRESENT /\ RELATION \in {"equal", "subpath"}
        /\ state # "unresolved") => state = "accepted"

InvalidPathSafety ==
    (~WORKING_DIR_PRESENT \/ RELATION = "outside") =>
        state # "accepted"

NoCrashFixed == USE_FIXED => state # "crashed"

=============================================================================
