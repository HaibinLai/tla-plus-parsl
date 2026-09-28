--------------------------- MODULE ParslAzureProviderSubmit ---------------------------
EXTENDS Naturals

(***************************************************************************
 * AzureProvider.submit provisioning boundary.
 *
 * The implementation creates a VM, appends its name to instances, and then
 * registers a resource before attaching a disk, starting the VM, and issuing
 * the worker command.  A later API failure can therefore leave partial state.
 * The fixed path rolls back the registration and instance tracking on setup
 * failure.
 ***************************************************************************)

CONSTANT FIXED

Phases == {"none", "vm_created", "registered", "started", "submitted", "failed"}

VARIABLES phase, resourceRegistered, instanceTracked
vars == <<phase, resourceRegistered, instanceTracked>>

Init ==
    /\ FIXED \in BOOLEAN
    /\ phase = "none"
    /\ resourceRegistered = FALSE
    /\ instanceTracked = FALSE

CreateVm ==
    /\ phase = "none"
    /\ phase' = "vm_created"
    /\ instanceTracked' = TRUE
    /\ UNCHANGED resourceRegistered

RegisterResource ==
    /\ phase = "vm_created"
    /\ phase' = "registered"
    /\ resourceRegistered' = TRUE
    /\ UNCHANGED instanceTracked

AttachAndStart ==
    /\ phase = "registered"
    /\ phase' = "started"
    /\ UNCHANGED <<resourceRegistered, instanceTracked>>

RunWorkerCommand ==
    /\ phase = "started"
    /\ phase' = "submitted"
    /\ UNCHANGED <<resourceRegistered, instanceTracked>>

SetupFails ==
    /\ phase = "registered"
    /\ phase' = "failed"
    /\ IF FIXED THEN
          /\ resourceRegistered' = FALSE
          /\ instanceTracked' = FALSE
       ELSE
          /\ UNCHANGED <<resourceRegistered, instanceTracked>>

Next ==
    \/ CreateVm
    \/ RegisterResource
    \/ AttachAndStart
    \/ RunWorkerCommand
    \/ SetupFails
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ phase \in Phases
    /\ resourceRegistered \in BOOLEAN
    /\ instanceTracked \in BOOLEAN

NoPartialFailure ==
    phase = "failed" => ~resourceRegistered /\ ~instanceTracked

RegistrationRequiresTracking ==
    resourceRegistered => instanceTracked

=============================================================================
