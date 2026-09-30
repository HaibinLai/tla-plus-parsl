--------------------------- MODULE ParslZipTraversal ---------------------------
EXTENDS Naturals

(***************************************************************************
 * ZipFileStaging joins an archive member name directly with the executor
 * working directory.  A member containing ../ therefore escapes that
 * directory unless the path is rejected or normalized safely.
 ***************************************************************************)

CONSTANTS MEMBER_ESCAPES, USE_FIXED
VARIABLES state, publishedInside
vars == <<state, publishedInside>>

Init ==
    /\ MEMBER_ESCAPES \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ state = "ready"
    /\ publishedInside = TRUE

StageIn ==
    /\ state = "ready"
    /\ state' = IF MEMBER_ESCAPES /\ ~USE_FIXED THEN "escaped" ELSE "published"
    /\ publishedInside' = IF MEMBER_ESCAPES /\ ~USE_FIXED THEN FALSE ELSE TRUE

Next ==
    \/ StageIn
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ MEMBER_ESCAPES \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ state \in {"ready", "escaped", "published"}
    /\ publishedInside \in BOOLEAN

TraversalSafety == state = "escaped" => publishedInside

=============================================================================
