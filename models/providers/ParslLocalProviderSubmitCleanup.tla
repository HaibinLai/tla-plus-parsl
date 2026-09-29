--------------------------- MODULE ParslLocalProviderSubmitCleanup ---------------------------
EXTENDS Naturals

(***************************************************************************
 * LocalProvider.submit script cleanup.
 *
 * submit() writes a worker script before launching it.  If the launch command
 * fails, the current path raises SubmitException but leaves that script in
 * script_dir.  USE_FIXED models removing the newly-created script before
 * reporting failure.
 *************************************************************************** *)

CONSTANT USE_FIXED, LAUNCH_SUCCEEDS

VARIABLES phase, scriptPresent, resourceTracked
vars == <<phase, scriptPresent, resourceTracked>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ LAUNCH_SUCCEEDS \in BOOLEAN
    /\ phase = "new"
    /\ scriptPresent = FALSE
    /\ resourceTracked = FALSE

WriteScript ==
    /\ phase = "new"
    /\ phase' = "script-written"
    /\ scriptPresent' = TRUE
    /\ UNCHANGED resourceTracked

Launch ==
    /\ phase = "script-written"
    /\ IF LAUNCH_SUCCEEDS
       THEN /\ phase' = "submitted"
            /\ resourceTracked' = TRUE
            /\ UNCHANGED scriptPresent
       ELSE /\ phase' = "failed"
            /\ resourceTracked' = FALSE
            /\ scriptPresent' = IF USE_FIXED THEN FALSE ELSE scriptPresent

Next ==
    \/ WriteScript
    \/ Launch
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ LAUNCH_SUCCEEDS \in BOOLEAN
    /\ phase \in {"new", "script-written", "submitted", "failed"}
    /\ scriptPresent \in BOOLEAN
    /\ resourceTracked \in BOOLEAN

FailedCleanupSafety ==
    phase = "failed" => /\ ~scriptPresent
                         /\ ~resourceTracked

SubmissionSafety == phase = "submitted" => scriptPresent /\ resourceTracked

=============================================================================
