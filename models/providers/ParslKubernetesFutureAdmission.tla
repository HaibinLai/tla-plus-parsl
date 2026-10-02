--------------------------- MODULE ParslKubernetesFutureAdmission ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Kubernetes provider status versus executor Future admission.
 *
 * KubernetesProvider.submit creates the pod and immediately stores RUNNING
 * locally, although the pod can still be Pending.  This composition connects
 * that provider state to a task Future and a monitoring status.  USE_FIXED
 * requires an observed Running pod phase before either task admission or a
 * running monitor event is published.
 ***************************************************************************)

CONSTANT USE_FIXED

PodPhases == {"absent", "Pending", "Running", "Succeeded", "Failed"}
LocalStates == {"absent", "running", "completed", "failed"}
FutureStates == {"none", "running", "done", "failed"}
MonitorStates == {"none", "running", "completed", "failed"}

VARIABLES pod, local, slot, future, monitor
vars == <<pod, local, slot, future, monitor>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ pod = "absent"
    /\ local = "absent"
    /\ slot = FALSE
    /\ future = "none"
    /\ monitor = "none"

SubmitPod ==
    /\ pod = "absent"
    /\ pod' = "Pending"
    /\ local' = "running"
    /\ slot' = TRUE
    /\ UNCHANGED <<future, monitor>>

PodRuns ==
    /\ pod = "Pending"
    /\ pod' = "Running"
    /\ UNCHANGED <<local, slot, future, monitor>>

AdmitTask ==
    /\ local = "running"
    /\ slot
    /\ IF USE_FIXED THEN pod = "Running" ELSE TRUE
    /\ future' = "running"
    /\ slot' = FALSE
    /\ UNCHANGED <<pod, local, monitor>>

PublishMonitor ==
    /\ local = "running"
    /\ IF USE_FIXED THEN pod = "Running" ELSE TRUE
    /\ monitor' = "running"
    /\ UNCHANGED <<pod, local, slot, future>>

PodSucceeds ==
    /\ pod = "Running"
    /\ pod' = "Succeeded"
    /\ local' = "completed"
    /\ future' = IF future = "running" THEN "done" ELSE future
    /\ monitor' = IF monitor = "running" THEN "completed" ELSE monitor
    /\ UNCHANGED slot

PodFails ==
    /\ pod \in {"Pending", "Running"}
    /\ pod' = "Failed"
    /\ local' = "failed"
    /\ future' = IF future = "running" THEN "failed" ELSE future
    /\ monitor' = IF monitor = "running" THEN "failed" ELSE monitor
    /\ UNCHANGED slot

Next ==
    \/ SubmitPod
    \/ PodRuns
    \/ AdmitTask
    \/ PublishMonitor
    \/ PodSucceeds
    \/ PodFails
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ pod \in PodPhases
    /\ local \in LocalStates
    /\ slot \in BOOLEAN
    /\ future \in FutureStates
    /\ monitor \in MonitorStates

FutureAdmissionSafety ==
    future = "running" => pod = "Running"

MonitorAdmissionSafety ==
    monitor = "running" => pod = "Running"

TerminalFutureConsistency ==
    future = "done" => local = "completed"

=============================================================================
