--------------------------- MODULE ParslGoogleCloudSubmitState ---------------------------
EXTENDS Naturals

(***************************************************************************
 * GoogleCloudProvider.submit translates the status returned by the create
 * request before publishing local resource bookkeeping.  A newly introduced
 * GCE status currently raises through direct dictionary indexing.  USE_FIXED
 * maps an unfamiliar status to UNKNOWN and still records the resource.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES phase, resourcePublished, mappedState
vars == <<phase, resourcePublished, mappedState>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ phase = "created"
    /\ resourcePublished = FALSE
    /\ mappedState = "none"

TranslateUnknownCreateState ==
    /\ phase = "created"
    /\ phase' = IF USE_FIXED THEN "submitted" ELSE "failed"
    /\ resourcePublished' = USE_FIXED
    /\ mappedState' = IF USE_FIXED THEN "unknown" ELSE "none"

Next == TranslateUnknownCreateState \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ phase \in {"created", "submitted", "failed"}
    /\ resourcePublished \in BOOLEAN
    /\ mappedState \in {"none", "unknown"}

UnknownStateSafety ==
    phase # "failed"

=============================================================================
