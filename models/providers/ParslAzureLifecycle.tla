--------------------------- MODULE ParslAzureLifecycle ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Small Azure provider lifecycle composition.
 *
 * Provisioning creates and registers a VM before disk attachment and worker
 * startup.  The same resource then passes through status translation and
 * cancellation.  The Current branch can retain partial records after setup
 * failure, under-report a running VM when status entries are reordered, and
 * retain a deleted VM in the local resource table.
 ***************************************************************************)

CONSTANTS USE_FIXED, STATUS_SWAPPED

Phases == {"new", "vm_created", "registered", "started", "submitted", "failed",
           "running", "pending", "cancelling", "done"}
ResourceStates == {"none", "pending", "running", "cancelled"}

VARIABLES phase, resource, remotePresent, instanceTracked, resourceRegistered,
          statusRead, observed, cancelRequested
vars == <<phase, resource, remotePresent, instanceTracked,
           resourceRegistered, statusRead, observed, cancelRequested>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ STATUS_SWAPPED \in BOOLEAN
    /\ phase = "new"
    /\ resource = "none"
    /\ remotePresent = FALSE
    /\ instanceTracked = FALSE
    /\ resourceRegistered = FALSE
    /\ statusRead = FALSE
    /\ observed = "none"
    /\ cancelRequested = FALSE

CreateVm ==
    /\ phase = "new"
    /\ phase' = "vm_created"
    /\ remotePresent' = TRUE
    /\ instanceTracked' = TRUE
    /\ resource' = "pending"
    /\ UNCHANGED <<resourceRegistered, statusRead, observed, cancelRequested>>

RegisterResource ==
    /\ phase = "vm_created"
    /\ phase' = "registered"
    /\ resourceRegistered' = TRUE
    /\ UNCHANGED <<resource, remotePresent, instanceTracked, statusRead,
                    observed, cancelRequested>>

SetupFails ==
    /\ phase = "registered"
    /\ phase' = "failed"
    /\ IF USE_FIXED
          THEN /\ instanceTracked' = FALSE
               /\ resourceRegistered' = FALSE
               /\ remotePresent' = FALSE
               /\ resource' = "none"
          ELSE /\ UNCHANGED <<instanceTracked, resourceRegistered,
                               remotePresent, resource>>
    /\ UNCHANGED <<statusRead, observed, cancelRequested>>

AttachAndStart ==
    /\ phase = "registered"
    /\ phase' = "started"
    /\ UNCHANGED <<resource, remotePresent, instanceTracked,
                    resourceRegistered, statusRead, observed, cancelRequested>>

RunWorkerCommand ==
    /\ phase = "started"
    /\ phase' = "submitted"
    /\ UNCHANGED <<resource, remotePresent, instanceTracked,
                    resourceRegistered, statusRead, observed, cancelRequested>>

ReadStatus ==
    /\ phase = "submitted"
    /\ phase' = IF USE_FIXED \/ ~STATUS_SWAPPED THEN "running" ELSE "pending"
    /\ resource' = IF USE_FIXED \/ ~STATUS_SWAPPED THEN "running" ELSE "pending"
    /\ statusRead' = TRUE
    /\ observed' = IF USE_FIXED \/ ~STATUS_SWAPPED THEN "running" ELSE "pending"
    /\ UNCHANGED <<remotePresent, instanceTracked, resourceRegistered,
                    cancelRequested>>

BeginCancel ==
    /\ phase \in {"running", "pending"}
    /\ phase' = "cancelling"
    /\ UNCHANGED <<resource, remotePresent, instanceTracked,
                    resourceRegistered, statusRead, observed, cancelRequested>>

DeleteRemote ==
    /\ phase = "cancelling"
    /\ phase' = "done"
    /\ remotePresent' = FALSE
    /\ instanceTracked' = FALSE
    /\ resource' = "cancelled"
    /\ resourceRegistered' = IF USE_FIXED THEN FALSE ELSE resourceRegistered
    /\ cancelRequested' = TRUE
    /\ UNCHANGED <<statusRead, observed>>

Next ==
    \/ CreateVm
    \/ RegisterResource
    \/ SetupFails
    \/ AttachAndStart
    \/ RunWorkerCommand
    \/ ReadStatus
    \/ BeginCancel
    \/ DeleteRemote
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ phase \in Phases
    /\ resource \in ResourceStates
    /\ remotePresent \in BOOLEAN
    /\ instanceTracked \in BOOLEAN
    /\ resourceRegistered \in BOOLEAN
    /\ statusRead \in BOOLEAN
    /\ observed \in {"none", "pending", "running"}
    /\ cancelRequested \in BOOLEAN

FailureCleanupSafety ==
    phase = "failed" => ~instanceTracked /\ ~resourceRegistered /\ ~remotePresent

StatusOrderingSafety == statusRead => observed = "running"

NoStaleResource == ~remotePresent => ~resourceRegistered

CancellationSafety == cancelRequested => phase = "done" /\ resource = "cancelled"

=============================================================================
