--------------------------- MODULE ParslResourceAdmission ---------------------------
EXTENDS Naturals, FiniteSets

(***************************************************************************
 * Resource specification and worker admission.
 *
 * This models the WorkQueueExecutor resource_specification contract: unknown
 * fields are rejected; cores/memory/disk must be supplied together unless
 * autolabel is enabled; valid tasks wait until a worker has enough resources.
 ***************************************************************************)

CONSTANTS TASKS, AUTOLABEL, MAX_TASKS,
          WORKER_CORES, WORKER_MEMORY, WORKER_DISK, WORKER_GPUS,
          MAX_REJECTIONS

SpecKinds == {"none", "complete", "partial", "unknown", "gpus"}

ReqCores(s) == IF s = "complete" THEN 2 ELSE IF s = "gpus" THEN 1 ELSE IF s = "partial" THEN 1 ELSE 0
ReqMemory(s) == IF s = "complete" THEN 2 ELSE IF s = "gpus" THEN 1 ELSE IF s = "partial" THEN 1 ELSE 0
ReqDisk(s) == IF s = "complete" THEN 2 ELSE IF s = "gpus" THEN 1 ELSE IF s = "partial" THEN 1 ELSE 0
ReqGpus(s) == IF s = "gpus" THEN 1 ELSE 0

ValidSpec(s) ==
    /\ s \in SpecKinds
    /\ s # "unknown"
    /\ (s # "partial" \/ AUTOLABEL)

Fits(s) ==
    /\ ReqCores(s) <= WORKER_CORES
    /\ ReqMemory(s) <= WORKER_MEMORY
    /\ ReqDisk(s) <= WORKER_DISK
    /\ ReqGpus(s) <= WORKER_GPUS

VARIABLES queued, running, completed, specKind,
          usedCores, usedMemory, usedDisk, usedGpus, rejected
vars == <<queued, running, completed, specKind,
          usedCores, usedMemory, usedDisk, usedGpus, rejected>>

Init ==
    /\ TASKS # {}
    /\ MAX_TASKS > 0
    /\ WORKER_CORES > 0
    /\ WORKER_MEMORY > 0
    /\ WORKER_DISK > 0
    /\ MAX_REJECTIONS > 0
    /\ queued = {}
    /\ running = {}
    /\ completed = {}
    /\ specKind = [t \in TASKS |-> "none"]
    /\ usedCores = 0
    /\ usedMemory = 0
    /\ usedDisk = 0
    /\ usedGpus = 0
    /\ rejected = 0

Submit(t, s) ==
    /\ t \in TASKS
    /\ s \in SpecKinds
    /\ t \notin queued \cup running \cup completed
    /\ Cardinality(queued) < MAX_TASKS
    /\ ValidSpec(s)
    /\ queued' = queued \cup {t}
    /\ specKind' = [specKind EXCEPT ![t] = s]
    /\ UNCHANGED <<running, completed, usedCores, usedMemory,
                    usedDisk, usedGpus, rejected>>

RejectSubmit(t, s) ==
    /\ t \in TASKS
    /\ s \in SpecKinds
    /\ t \notin queued \cup running \cup completed
    /\ rejected < MAX_REJECTIONS
    /\ ~ValidSpec(s)
    /\ rejected' = rejected + 1
    /\ UNCHANGED <<queued, running, completed, specKind,
                    usedCores, usedMemory, usedDisk, usedGpus>>

Dispatch(t) ==
    /\ t \in queued
    /\ LET s == specKind[t] IN Fits(s)
    /\ usedCores + ReqCores(specKind[t]) <= WORKER_CORES
    /\ usedMemory + ReqMemory(specKind[t]) <= WORKER_MEMORY
    /\ usedDisk + ReqDisk(specKind[t]) <= WORKER_DISK
    /\ usedGpus + ReqGpus(specKind[t]) <= WORKER_GPUS
    /\ queued' = queued \ {t}
    /\ running' = running \cup {t}
    /\ usedCores' = usedCores + ReqCores(specKind[t])
    /\ usedMemory' = usedMemory + ReqMemory(specKind[t])
    /\ usedDisk' = usedDisk + ReqDisk(specKind[t])
    /\ usedGpus' = usedGpus + ReqGpus(specKind[t])
    /\ UNCHANGED <<completed, specKind, rejected>>

Complete(t) ==
    /\ t \in running
    /\ running' = running \ {t}
    /\ completed' = completed \cup {t}
    /\ usedCores' = usedCores - ReqCores(specKind[t])
    /\ usedMemory' = usedMemory - ReqMemory(specKind[t])
    /\ usedDisk' = usedDisk - ReqDisk(specKind[t])
    /\ usedGpus' = usedGpus - ReqGpus(specKind[t])
    /\ UNCHANGED <<queued, specKind, rejected>>

Next ==
    \/ \E t \in TASKS, s \in SpecKinds : Submit(t, s) \/ RejectSubmit(t, s)
    \/ \E t \in TASKS : Dispatch(t) \/ Complete(t)
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ queued \subseteq TASKS
    /\ running \subseteq TASKS
    /\ completed \subseteq TASKS
    /\ queued \cap running = {}
    /\ queued \cap completed = {}
    /\ running \cap completed = {}
    /\ specKind \in [TASKS -> SpecKinds]
    /\ usedCores \in 0..WORKER_CORES
    /\ usedMemory \in 0..WORKER_MEMORY
    /\ usedDisk \in 0..WORKER_DISK
    /\ usedGpus \in 0..WORKER_GPUS
    /\ rejected \in 0..MAX_REJECTIONS

AdmissionSafety ==
    /\ \A t \in queued \cup running \cup completed : ValidSpec(specKind[t])
    /\ \A t \in running : Fits(specKind[t])

ResourceSafety ==
    /\ usedCores <= WORKER_CORES
    /\ usedMemory <= WORKER_MEMORY
    /\ usedDisk <= WORKER_DISK
    /\ usedGpus <= WORKER_GPUS

CompletionReleasesResources ==
    \A t \in completed : t \notin running

=============================================================================
