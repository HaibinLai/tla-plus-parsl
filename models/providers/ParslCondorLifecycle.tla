--------------------------- MODULE ParslCondorLifecycle ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Small HTCondor provider lifecycle composition.
 *
 * A successful condor_submit creates a pending local resource.  condor_q
 * may fail, return malformed/foreign records, or report a valid running
 * record.  The resource can then be cancelled in a later chunk.  The Current
 * branch aborts the lifecycle on the parser boundary; the Fixed branch keeps
 * the previous status, ignores unrelated records, and reaches cancellation.
 ***************************************************************************)

CONSTANT USE_FIXED

Phases == {"new", "submitted", "polling", "running", "cancelling", "done", "failed"}
ResourceStates == {"none", "pending", "running", "cancelled"}

VARIABLES phase, resource, statusSeen, commandFailure, malformedSeen,
          foreignSeen, cancelRequested
vars == <<phase, resource, statusSeen, commandFailure, malformedSeen,
           foreignSeen, cancelRequested>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ phase = "new"
    /\ resource = "none"
    /\ statusSeen = FALSE
    /\ commandFailure = FALSE
    /\ malformedSeen = FALSE
    /\ foreignSeen = FALSE
    /\ cancelRequested = FALSE

Submit ==
    /\ phase = "new"
    /\ phase' = "submitted"
    /\ resource' = "pending"
    /\ UNCHANGED <<statusSeen, commandFailure, malformedSeen,
                    foreignSeen, cancelRequested>>

BeginPoll ==
    /\ phase = "submitted"
    /\ phase' = "polling"
    /\ UNCHANGED <<resource, statusSeen, commandFailure, malformedSeen,
                    foreignSeen, cancelRequested>>

FailedCommand ==
    /\ phase = "polling"
    /\ phase' = IF USE_FIXED THEN "polling" ELSE "failed"
    /\ commandFailure' = TRUE
    /\ UNCHANGED <<resource, statusSeen, malformedSeen, foreignSeen,
                    cancelRequested>>

MalformedRecord ==
    /\ phase = "polling"
    /\ phase' = IF USE_FIXED THEN "polling" ELSE "failed"
    /\ malformedSeen' = TRUE
    /\ UNCHANGED <<resource, statusSeen, commandFailure, foreignSeen,
                    cancelRequested>>

ForeignRecord ==
    /\ phase = "polling"
    /\ phase' = IF USE_FIXED THEN "polling" ELSE "failed"
    /\ foreignSeen' = TRUE
    /\ UNCHANGED <<resource, statusSeen, commandFailure, malformedSeen,
                    cancelRequested>>

ValidRecord ==
    /\ phase = "polling"
    /\ phase' = "running"
    /\ resource' = "running"
    /\ statusSeen' = TRUE
    /\ UNCHANGED <<commandFailure, malformedSeen, foreignSeen,
                    cancelRequested>>

BeginCancel ==
    /\ phase = "running"
    /\ phase' = "cancelling"
    /\ UNCHANGED <<resource, statusSeen, commandFailure, malformedSeen,
                    foreignSeen, cancelRequested>>

CancelChunk ==
    /\ phase = "cancelling"
    /\ phase' = "done"
    /\ resource' = "cancelled"
    /\ cancelRequested' = TRUE
    /\ UNCHANGED <<statusSeen, commandFailure, malformedSeen, foreignSeen>>

Next ==
    \/ Submit
    \/ BeginPoll
    \/ FailedCommand
    \/ MalformedRecord
    \/ ForeignRecord
    \/ ValidRecord
    \/ BeginCancel
    \/ CancelChunk
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ phase \in Phases
    /\ resource \in ResourceStates
    /\ statusSeen \in BOOLEAN
    /\ commandFailure \in BOOLEAN
    /\ malformedSeen \in BOOLEAN
    /\ foreignSeen \in BOOLEAN
    /\ cancelRequested \in BOOLEAN

NoAbort == phase # "failed"

ResourceAdmission == phase # "new" => resource # "none"

StatusResourceSafety == statusSeen => resource \in {"running", "cancelled"}

CancellationSafety == cancelRequested => phase = "done" /\ resource = "cancelled"

=============================================================================
