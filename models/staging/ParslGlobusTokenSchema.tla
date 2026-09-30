--------------------------- MODULE ParslGlobusTokenSchema ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Globus token-file schema admission.
 *
 * A syntactically valid JSON token file can still lack the
 * transfer.api.globus.org record required by _get_native_app_authorizer.
 * The current implementation treats that mapping as usable and raises a raw
 * KeyError.  The fixed branch treats a missing service record as unusable and
 * enters the normal authentication path.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES tokenLoaded, serviceRecordPresent, authState
vars == <<tokenLoaded, serviceRecordPresent, authState>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ tokenLoaded = TRUE
    /\ serviceRecordPresent = FALSE
    /\ authState = "not_started"

UseLoadedToken ==
    /\ tokenLoaded
    /\ ~serviceRecordPresent
    /\ authState' = IF USE_FIXED THEN "reauthenticate" ELSE "crashed"
    /\ UNCHANGED <<tokenLoaded, serviceRecordPresent>>

Authenticate ==
    /\ authState = "reauthenticate"
    /\ authState' = "authenticated"
    /\ UNCHANGED <<tokenLoaded, serviceRecordPresent>>

Next ==
    \/ UseLoadedToken
    \/ Authenticate
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ tokenLoaded \in BOOLEAN
    /\ serviceRecordPresent \in BOOLEAN
    /\ authState \in {"not_started", "reauthenticate", "authenticated", "crashed"}

TokenSchemaSafety == authState # "crashed"

=============================================================================
