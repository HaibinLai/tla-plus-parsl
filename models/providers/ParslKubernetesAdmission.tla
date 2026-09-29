--------------------------- MODULE ParslKubernetesAdmission ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Kubernetes pod phase versus executor task admission.
 *
 * KubernetesProvider.submit creates a pod before the pod is actually Running.
 * The current branch records the local job as RUNNING immediately, allowing
 * an executor task to be admitted while the pod is still Pending.  The fixed
 * branch reports PENDING until a poll observes Running.
 ***************************************************************************)

CONSTANT USE_FIXED

PodStates == {"absent", "pending", "running", "succeeded", "failed"}
JobStates == {"none", "pending", "running", "completed", "failed"}
TaskStates == {"queued", "running", "done", "failed"}

VARIABLES pod, job, task
vars == <<pod, job, task>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ pod = "absent"
    /\ job = "none"
    /\ task = "queued"

SubmitPod ==
    /\ pod = "absent"
    /\ pod' = "pending"
    /\ job' = IF USE_FIXED THEN "pending" ELSE "running"
    /\ UNCHANGED task

PollRunning ==
    /\ pod = "pending"
    /\ pod' = "running"
    /\ job' = "running"
    /\ UNCHANGED task

PollTerminal(phase) ==
    /\ pod = "running"
    /\ phase \in {"succeeded", "failed"}
    /\ pod' = phase
    /\ job' = IF phase = "succeeded" THEN "completed" ELSE "failed"
    /\ task' = IF task = "running" THEN "failed" ELSE task

AdmitTask ==
    /\ task = "queued"
    /\ job = "running"
    /\ task' = "running"
    /\ UNCHANGED <<pod, job>>

CompleteTask ==
    /\ task = "running"
    /\ pod = "running"
    /\ task' = "done"
    /\ UNCHANGED <<pod, job>>

FailTask ==
    /\ task = "running"
    /\ pod \in {"failed", "succeeded"}
    /\ task' = "failed"
    /\ UNCHANGED <<pod, job>>

Next ==
    \/ SubmitPod
    \/ PollRunning
    \/ \E phase \in {"succeeded", "failed"} : PollTerminal(phase)
    \/ AdmitTask
    \/ CompleteTask
    \/ FailTask
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ pod \in PodStates
    /\ job \in JobStates
    /\ task \in TaskStates

AdmissionSafety ==
    task = "running" => pod = "running"

JobPhaseSafety ==
    job = "running" => pod = "running"

TerminalSafety ==
    task = "done" => pod \in {"running", "succeeded", "failed"}
                      /\ job \in {"running", "completed", "failed"}

=============================================================================
