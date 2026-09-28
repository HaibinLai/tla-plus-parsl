--------------------------- MODULE ParslFTPStage ---------------------------
EXTENDS Naturals

(***************************************************************************
 * FTP in-task staging failure cleanup.
 *
 * A failed retrbinary call can write a prefix before raising.  The user
 * function must not run, and a corrected wrapper should remove the partial
 * local file rather than leaving it as a misleading input artifact.
 ***************************************************************************)

CONSTANT TRANSFER_SUCCEEDS, USE_FIXED

Phases == {"transfer", "succeeded", "failed"}

VARIABLES phase, artifactPresent, appRan
vars == <<phase, artifactPresent, appRan>>

Init ==
    /\ TRANSFER_SUCCEEDS \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ phase = "transfer"
    /\ artifactPresent = FALSE
    /\ appRan = FALSE

ReceiveBytes ==
    /\ phase = "transfer"
    /\ artifactPresent' = IF TRANSFER_SUCCEEDS THEN TRUE
                         ELSE IF USE_FIXED THEN FALSE ELSE TRUE
    /\ IF TRANSFER_SUCCEEDS
          THEN phase' = "succeeded"
               /\ appRan' = TRUE
          ELSE phase' = "failed"
               /\ appRan' = FALSE

Next ==
    \/ ReceiveBytes
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ phase \in Phases
    /\ artifactPresent \in BOOLEAN
    /\ appRan \in BOOLEAN

FailureCleanup ==
    phase = "failed" =>
        /\ ~appRan
        /\ ~artifactPresent

SuccessSafety ==
    phase = "succeeded" =>
        /\ artifactPresent
        /\ appRan

=============================================================================
