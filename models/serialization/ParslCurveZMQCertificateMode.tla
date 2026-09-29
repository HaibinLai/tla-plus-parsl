--------------------------- MODULE ParslCurveZMQCertificateMode ---------------------------
EXTENDS Naturals

(***************************************************************************
 * CurveZMQ certificate loading.
 *
 * curvezmq._load_certificate requires a private (0700) certificate directory,
 * then requires a secret-key file.  The finite model abstracts directory mode
 * and key presence while preserving the safety condition for loaded keys.
 *************************************************************************** *)

CONSTANTS PRIVATE_DIRECTORY, SECRET_KEY_PRESENT
VARIABLES state, keyLoaded
vars == <<state, keyLoaded>>

Init ==
    /\ PRIVATE_DIRECTORY \in BOOLEAN
    /\ SECRET_KEY_PRESENT \in BOOLEAN
    /\ state = "unloaded"
    /\ keyLoaded = FALSE

LoadKey ==
    /\ state = "unloaded"
    /\ PRIVATE_DIRECTORY
    /\ SECRET_KEY_PRESENT
    /\ state' = "loaded"
    /\ keyLoaded' = TRUE

RejectDirectory ==
    /\ state = "unloaded"
    /\ ~PRIVATE_DIRECTORY
    /\ state' = "rejected"
    /\ UNCHANGED keyLoaded

RejectKey ==
    /\ state = "unloaded"
    /\ PRIVATE_DIRECTORY
    /\ ~SECRET_KEY_PRESENT
    /\ state' = "rejected"
    /\ UNCHANGED keyLoaded

Next == LoadKey \/ RejectDirectory \/ RejectKey \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in {"unloaded", "loaded", "rejected"}
    /\ keyLoaded \in BOOLEAN

CertificateSafety ==
    keyLoaded => PRIVATE_DIRECTORY /\ SECRET_KEY_PRESENT
=============================================================================
