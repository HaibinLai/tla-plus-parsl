--------------------------- MODULE ParslZipPathValidation ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Zip staging URL validation.
 *
 * ZipFileStaging.is_zip_url currently checks only the URI scheme.  A path
 * without the required ".zip/" separator reaches zip_path_split and is
 * silently truncated.  USE_FIXED models rejecting the malformed URL before
 * staging.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES urlValid, accepted, pathDerived
vars == <<urlValid, accepted, pathDerived>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ urlValid = FALSE
    /\ accepted = FALSE
    /\ pathDerived = FALSE

CheckURL ==
    /\ ~urlValid
    /\ accepted' = ~USE_FIXED
    /\ pathDerived' = ~USE_FIXED
    /\ UNCHANGED urlValid

CheckValidURL ==
    /\ urlValid
    /\ accepted' = TRUE
    /\ pathDerived' = TRUE
    /\ UNCHANGED urlValid

Next ==
    \/ CheckURL
    \/ CheckValidURL
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ urlValid \in BOOLEAN
    /\ accepted \in BOOLEAN
    /\ pathDerived \in BOOLEAN

MalformedPathSafety ==
    ~urlValid => ~accepted /\ ~pathDerived

=============================================================================
