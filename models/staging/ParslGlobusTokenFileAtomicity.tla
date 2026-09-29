--------------------------- MODULE ParslGlobusTokenFileAtomicity ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Globus token-cache publication.
 *
 * ``_save_tokens_to_file`` opens the existing token file with mode ``w``
 * before serializing JSON.  A serialization failure can therefore truncate
 * the last valid token set.  USE_FIXED models writing a temporary file and
 * replacing the destination only after serialization succeeds.
 *************************************************************************** *)

CONSTANT USE_FIXED
VARIABLES state, tokenFile
vars == <<state, tokenFile>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ state = "old-valid"
    /\ tokenFile = "valid"

SerializeFailure ==
    /\ state = "old-valid"
    /\ state' = "write-failed"
    /\ tokenFile' = IF USE_FIXED THEN "valid" ELSE "empty"

SerializeSuccess ==
    /\ state = "old-valid"
    /\ state' = "new-valid"
    /\ tokenFile' = "new"

Next ==
    \/ SerializeFailure
    \/ SerializeSuccess
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ state \in {"old-valid", "write-failed", "new-valid"}
    /\ tokenFile \in {"valid", "empty", "new"}

FailurePreservesLastValidTokens ==
    state = "write-failed" => tokenFile = "valid"

=============================================================================
