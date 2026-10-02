--------------------------- MODULE ParslGoogleCloudLifecycle ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Small Google Cloud provider lifecycle composition.
 *
 * Submission publishes a VM in local resource bookkeeping.  A status batch
 * contains one missing/failed remote lookup and one healthy VM.  The Current
 * provider lets the first API exception abort the whole batch; the Fixed
 * branch isolates the failed observation, preserves the healthy result, and
 * keeps the resource cancellable.
 ***************************************************************************)

CONSTANT USE_FIXED

Phases == {"new", "submitted", "status", "running", "cancelling", "done", "failed"}
ResourceStates == {"none", "pending", "running", "cancelled"}

VARIABLES phase, resource, failedObservation, healthyObservation,
          healthySeen, cancelRequested
vars == <<phase, resource, failedObservation, healthyObservation,
           healthySeen, cancelRequested>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ phase = "new"
    /\ resource = "none"
    /\ failedObservation = "none"
    /\ healthyObservation = "none"
    /\ healthySeen = FALSE
    /\ cancelRequested = FALSE

Submit ==
    /\ phase = "new"
    /\ phase' = "submitted"
    /\ resource' = "pending"
    /\ UNCHANGED <<failedObservation, healthyObservation, healthySeen,
                    cancelRequested>>

BeginStatus ==
    /\ phase = "submitted"
    /\ phase' = "status"
    /\ UNCHANGED <<resource, failedObservation, healthyObservation,
                    healthySeen, cancelRequested>>

HandleStatusBatch ==
    /\ phase = "status"
    /\ IF USE_FIXED
          THEN /\ phase' = "running"
               /\ resource' = "running"
               /\ failedObservation' = "unknown"
               /\ healthyObservation' = "running"
               /\ healthySeen' = TRUE
          ELSE /\ phase' = "failed"
               /\ UNCHANGED <<resource, failedObservation,
                               healthyObservation, healthySeen>>
    /\ UNCHANGED cancelRequested

BeginCancel ==
    /\ phase = "running"
    /\ phase' = "cancelling"
    /\ UNCHANGED <<resource, failedObservation, healthyObservation,
                    healthySeen, cancelRequested>>

DeleteInstance ==
    /\ phase = "cancelling"
    /\ phase' = "done"
    /\ resource' = "cancelled"
    /\ cancelRequested' = TRUE
    /\ UNCHANGED <<failedObservation, healthyObservation, healthySeen>>

Next ==
    \/ Submit
    \/ BeginStatus
    \/ HandleStatusBatch
    \/ BeginCancel
    \/ DeleteInstance
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ phase \in Phases
    /\ resource \in ResourceStates
    /\ failedObservation \in {"none", "unknown"}
    /\ healthyObservation \in {"none", "running"}
    /\ healthySeen \in BOOLEAN
    /\ cancelRequested \in BOOLEAN

StatusBatchSafety == phase # "failed"

HealthyObservationSafety ==
    phase \in {"running", "cancelling", "done"} => healthySeen

CancellationSafety == cancelRequested => resource = "cancelled"

=============================================================================
