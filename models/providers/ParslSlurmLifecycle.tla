--------------------------- MODULE ParslSlurmLifecycle ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Small Slurm provider lifecycle composition.
 *
 * A valid sbatch submission creates one local resource.  The status poll may
 * contain a foreign record, a malformed line, and a duplicate record before a
 * valid running status.  Cancellation then sees a known ID followed by a
 * stale local ID.  The Current branch aborts the lifecycle on those parser or
 * bookkeeping boundaries; the Fixed branch isolates malformed/foreign/
 * duplicate records and treats stale cancellation as idempotent.
 ***************************************************************************)

CONSTANT USE_FIXED

Phases == {"new", "submitted", "polling", "running", "cancelling", "done", "failed"}
ResourceStates == {"none", "pending", "running", "cancelled"}

VARIABLES phase, resource, knownCancelled, statusSeen, malformedSeen,
          foreignSeen, duplicateSeen
vars == <<phase, resource, knownCancelled, statusSeen, malformedSeen,
           foreignSeen, duplicateSeen>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ phase = "new"
    /\ resource = "none"
    /\ knownCancelled = FALSE
    /\ statusSeen = FALSE
    /\ malformedSeen = FALSE
    /\ foreignSeen = FALSE
    /\ duplicateSeen = FALSE

Submit ==
    /\ phase = "new"
    /\ phase' = "submitted"
    /\ resource' = "pending"
    /\ UNCHANGED <<knownCancelled, statusSeen, malformedSeen,
                    foreignSeen, duplicateSeen>>

BeginPoll ==
    /\ phase = "submitted"
    /\ phase' = "polling"
    /\ UNCHANGED <<resource, knownCancelled, statusSeen, malformedSeen,
                    foreignSeen, duplicateSeen>>

ForeignRecord ==
    /\ phase = "polling"
    /\ phase' = IF USE_FIXED THEN "polling" ELSE "failed"
    /\ foreignSeen' = TRUE
    /\ UNCHANGED <<resource, knownCancelled, statusSeen, malformedSeen,
                    duplicateSeen>>

MalformedRecord ==
    /\ phase = "polling"
    /\ phase' = IF USE_FIXED THEN "polling" ELSE "failed"
    /\ malformedSeen' = TRUE
    /\ UNCHANGED <<resource, knownCancelled, statusSeen, foreignSeen,
                    duplicateSeen>>

ValidStatus ==
    /\ phase = "polling"
    /\ phase' = "running"
    /\ resource' = "running"
    /\ statusSeen' = TRUE
    /\ UNCHANGED <<knownCancelled, malformedSeen, foreignSeen, duplicateSeen>>

DuplicateRecord ==
    /\ phase = "running"
    /\ phase' = IF USE_FIXED THEN "running" ELSE "failed"
    /\ duplicateSeen' = TRUE
    /\ UNCHANGED <<resource, knownCancelled, statusSeen, malformedSeen,
                    foreignSeen>>

BeginCancel ==
    /\ phase = "running"
    /\ phase' = "cancelling"
    /\ UNCHANGED <<resource, knownCancelled, statusSeen, malformedSeen,
                    foreignSeen, duplicateSeen>>

CancelKnown ==
    /\ phase = "cancelling"
    /\ knownCancelled = FALSE
    /\ knownCancelled' = TRUE
    /\ resource' = "cancelled"
    /\ UNCHANGED <<phase, statusSeen, malformedSeen, foreignSeen, duplicateSeen>>

CancelStale ==
    /\ phase = "cancelling"
    /\ knownCancelled
    /\ phase' = IF USE_FIXED THEN "done" ELSE "failed"
    /\ UNCHANGED <<resource, knownCancelled, statusSeen, malformedSeen,
                    foreignSeen, duplicateSeen>>

Next ==
    \/ Submit
    \/ BeginPoll
    \/ ForeignRecord
    \/ MalformedRecord
    \/ ValidStatus
    \/ DuplicateRecord
    \/ BeginCancel
    \/ CancelKnown
    \/ CancelStale
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ phase \in Phases
    /\ resource \in ResourceStates
    /\ knownCancelled \in BOOLEAN
    /\ statusSeen \in BOOLEAN
    /\ malformedSeen \in BOOLEAN
    /\ foreignSeen \in BOOLEAN
    /\ duplicateSeen \in BOOLEAN

NoAbort == phase # "failed"

ResourceAdmission == phase # "new" => resource # "none"

StatusRequiresResource == statusSeen => resource \in {"running", "cancelled"}

CancelTerminality == phase = "done" => resource = "cancelled"

=============================================================================
