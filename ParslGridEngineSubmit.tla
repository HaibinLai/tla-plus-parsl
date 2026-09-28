--------------------------- MODULE ParslGridEngineSubmit ---------------------------
EXTENDS Naturals

(***************************************************************************
 * GridEngineProvider.submit writes a script, invokes qsub, and registers the
 * first non-empty line of successful stdout as a pending resource.  A command
 * failure or successful empty output returns no job and leaves resources
 * unchanged.
 *************************************************************************** *)

CONSTANTS RETURN_CODE, OUTPUT_KIND

OutputKinds == {"job_id", "empty"}
Phases == {"initial", "script_written", "submitted", "registered", "no_job", "failed"}
VARIABLES phase, resourceRegistered
vars == <<phase, resourceRegistered>>

Init ==
    /\ RETURN_CODE \in {0, 1}
    /\ OUTPUT_KIND \in OutputKinds
    /\ phase = "initial"
    /\ resourceRegistered = FALSE

WriteScript ==
    /\ phase = "initial"
    /\ phase' = "script_written"
    /\ UNCHANGED resourceRegistered

SubmitCommand ==
    /\ phase = "script_written"
    /\ phase' = "submitted"
    /\ UNCHANGED resourceRegistered

CommandFails ==
    /\ phase = "submitted"
    /\ RETURN_CODE = 1
    /\ phase' = "failed"
    /\ UNCHANGED resourceRegistered

EmptySuccess ==
    /\ phase = "submitted"
    /\ RETURN_CODE = 0
    /\ OUTPUT_KIND = "empty"
    /\ phase' = "no_job"
    /\ UNCHANGED resourceRegistered

RegisterJob ==
    /\ phase = "submitted"
    /\ RETURN_CODE = 0
    /\ OUTPUT_KIND = "job_id"
    /\ phase' = "registered"
    /\ resourceRegistered' = TRUE

Next ==
    \/ WriteScript
    \/ SubmitCommand
    \/ CommandFails
    \/ EmptySuccess
    \/ RegisterJob
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ phase \in Phases
    /\ resourceRegistered \in BOOLEAN

RegistrationSafety ==
    phase = "registered" => resourceRegistered

NoOrphanResource ==
    phase \in {"failed", "no_job"} => ~resourceRegistered

=============================================================================
