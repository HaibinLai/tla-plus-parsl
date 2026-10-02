--------------------------- MODULE ParslAwsLifecycle ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Small AWS provider lifecycle composition.
 *
 * A submitted EC2 instance is polled through either a normal response or a
 * response that omits the requested instance.  Before cancellation, local
 * bookkeeping may already have forgotten the ID.  The Current branch leaves
 * the status request incomplete and raises on successful termination of the
 * stale local ID; the Fixed branch records UNKNOWN and makes cleanup idempotent.
 ***************************************************************************)

CONSTANT USE_FIXED

Phases == {"new", "submitted", "polling", "ready", "running", "cancelling", "done", "failed"}
ResourceStates == {"none", "pending", "running", "unknown", "cancelled"}

VARIABLES phase, resource, remotePresent, localPresent, statusRead,
          cancelRequested
vars == <<phase, resource, remotePresent, localPresent, statusRead,
           cancelRequested>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ phase = "new"
    /\ resource = "none"
    /\ remotePresent = FALSE
    /\ localPresent = FALSE
    /\ statusRead = FALSE
    /\ cancelRequested = FALSE

Submit ==
    /\ phase = "new"
    /\ phase' = "submitted"
    /\ resource' = "pending"
    /\ remotePresent' = TRUE
    /\ localPresent' = TRUE
    /\ UNCHANGED <<statusRead, cancelRequested>>

BeginStatus ==
    /\ phase = "submitted"
    /\ phase' = "polling"
    /\ UNCHANGED <<resource, remotePresent, localPresent, statusRead,
                    cancelRequested>>

MissingResponse ==
    /\ phase = "polling"
    /\ IF USE_FIXED
          THEN /\ phase' = "ready"
               /\ resource' = "unknown"
          ELSE /\ phase' = "failed"
               /\ UNCHANGED resource
    /\ statusRead' = TRUE
    /\ UNCHANGED <<remotePresent, localPresent, cancelRequested>>

RunningResponse ==
    /\ phase = "polling"
    /\ phase' = "running"
    /\ resource' = "running"
    /\ statusRead' = TRUE
    /\ UNCHANGED <<remotePresent, localPresent, cancelRequested>>

ForgetLocalRecord ==
    /\ phase \in {"ready", "running"}
    /\ localPresent
    /\ localPresent' = FALSE
    /\ UNCHANGED <<phase, resource, remotePresent, statusRead,
                    cancelRequested>>

BeginCancel ==
    /\ phase \in {"ready", "running"}
    /\ phase' = "cancelling"
    /\ UNCHANGED <<resource, remotePresent, localPresent, statusRead,
                    cancelRequested>>

TerminateRemote ==
    /\ phase = "cancelling"
    /\ remotePresent
    /\ remotePresent' = FALSE
    /\ IF localPresent \/ USE_FIXED
          THEN /\ phase' = "done"
               /\ resource' = "cancelled"
               /\ localPresent' = FALSE
          ELSE /\ phase' = "failed"
               /\ UNCHANGED <<resource, localPresent>>
    /\ cancelRequested' = TRUE
    /\ UNCHANGED statusRead

Next ==
    \/ Submit
    \/ BeginStatus
    \/ MissingResponse
    \/ RunningResponse
    \/ ForgetLocalRecord
    \/ BeginCancel
    \/ TerminateRemote
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ phase \in Phases
    /\ resource \in ResourceStates
    /\ remotePresent \in BOOLEAN
    /\ localPresent \in BOOLEAN
    /\ statusRead \in BOOLEAN
    /\ cancelRequested \in BOOLEAN

NoAbort == phase # "failed"

StatusCompleteness ==
    statusRead => resource \in {"running", "unknown", "cancelled"}

NoStaleLocalResource ==
    ~remotePresent => ~localPresent

CancellationSafety ==
    cancelRequested => phase = "done" /\ resource = "cancelled"

=============================================================================
