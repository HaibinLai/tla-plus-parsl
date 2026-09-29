--------------------------- MODULE ParslMemoIgnoreOutputs ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Interaction between ignore_for_cache and the special outputs key.
 *
 * make_hash first removes every ignored key, then separately removes
 * `outputs` to hash it as an output reference.  Ignoring the known outputs
 * key therefore causes a second deletion in the current implementation.
 * The fixed branch treats the special key idempotently.
 ***************************************************************************)

CONSTANT USE_FIXED

Phases == {"ready", "ignored", "hashed", "raw_error"}

VARIABLES phase, outputsPresent
vars == <<phase, outputsPresent>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ phase = "ready"
    /\ outputsPresent = TRUE

ApplyIgnoreList ==
    /\ phase = "ready"
    /\ outputsPresent
    /\ phase' = "ignored"
    /\ outputsPresent' = FALSE

HashOutputsCurrent ==
    /\ ~USE_FIXED
    /\ phase = "ignored"
    /\ ~outputsPresent
    /\ phase' = "raw_error"
    /\ UNCHANGED outputsPresent

HashOutputsFixed ==
    /\ USE_FIXED
    /\ phase = "ignored"
    /\ ~outputsPresent
    /\ phase' = "hashed"
    /\ UNCHANGED outputsPresent

Next ==
    \/ ApplyIgnoreList
    \/ HashOutputsCurrent
    \/ HashOutputsFixed
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ phase \in Phases
    /\ outputsPresent \in BOOLEAN

NoRawOutputDeleteError == phase # "raw_error"

=============================================================================
