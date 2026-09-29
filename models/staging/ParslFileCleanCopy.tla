--------------------------- MODULE ParslFileCleanCopy ---------------------------
EXTENDS Naturals

(***************************************************************************
 * File.cleancopy object semantics.
 *
 * A File contains immutable global URL metadata and mutable site-local
 * staging metadata.  A clean copy must preserve the URL while clearing the
 * local path, so a DataFuture can carry the object to another site without
 * reusing an old worker-local pathname.  USE_CLEAN_COPY models that contract.
 *************************************************************************** *)

CONSTANT USE_CLEAN_COPY

VARIABLES originalURL, originalLocalPath, copyURL, copyLocalPath, state
vars == <<originalURL, originalLocalPath, copyURL, copyLocalPath, state>>

Init ==
    /\ USE_CLEAN_COPY \in BOOLEAN
    /\ originalURL = "https://source/input.bin"
    /\ originalLocalPath = "/site-a/input.bin"
    /\ copyURL = "none"
    /\ copyLocalPath = "none"
    /\ state = "original"

CreateCleanCopy ==
    /\ state = "original"
    /\ copyURL' = originalURL
    /\ copyLocalPath' = IF USE_CLEAN_COPY THEN "none" ELSE originalLocalPath
    /\ state' = "copied"
    /\ UNCHANGED <<originalURL, originalLocalPath>>

Next ==
    \/ CreateCleanCopy
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ originalURL = "https://source/input.bin"
    /\ originalLocalPath = "/site-a/input.bin"
    /\ copyURL \in {"none", originalURL}
    /\ copyLocalPath \in {"none", originalLocalPath}
    /\ state \in {"original", "copied"}

URLPreserved == state = "copied" => copyURL = originalURL
LocalPathIsClean == state = "copied" => copyLocalPath = "none"
OriginalNotMutated == originalLocalPath = "/site-a/input.bin"

=============================================================================
