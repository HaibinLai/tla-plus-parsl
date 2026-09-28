--------------------------- MODULE ParslTaskVineResults ---------------------------
EXTENDS Naturals, FiniteSets

(***************************************************************************
 * A focused TaskVineExecutor manager/collector model.
 *
 * submit() creates one executor-task Future and places a task on the manager
 * queue.  The manager reports either a result file or a TaskVine failure
 * reason.  The collector maps valid, missing, corrupt, and exception results
 * to the Future.  If the manager/submit process dies, collector finalization
 * fails every remaining outstanding Future.
 ***************************************************************************)

ManagerStates == {"up", "failed"}
CollectorStates == {"running", "stopped"}
TaskStates == {"absent", "submitted", "reported", "succeeded", "failed"}
FutureStates == {"none", "pending", "succeeded", "failed"}
Reports == {"valid", "missing", "corrupt", "task_exception", "no_result"}

VARIABLES managerState, collectorState, taskState, futureState,
          reportKind, outstanding
vars == <<managerState, collectorState, taskState, futureState,
          reportKind, outstanding>>

Init ==
    /\ managerState = "up"
    /\ collectorState = "running"
    /\ taskState = "absent"
    /\ futureState = "none"
    /\ reportKind = "none"
    /\ outstanding = FALSE

Submit ==
    /\ managerState = "up"
    /\ collectorState = "running"
    /\ taskState = "absent"
    /\ taskState' = "submitted"
    /\ futureState' = "pending"
    /\ outstanding' = TRUE
    /\ UNCHANGED <<managerState, collectorState, reportKind>>

Report(kind) ==
    /\ managerState = "up"
    /\ taskState = "submitted"
    /\ kind \in Reports
    /\ taskState' = "reported"
    /\ reportKind' = kind
    /\ UNCHANGED <<managerState, collectorState, futureState, outstanding>>

Collect ==
    /\ collectorState = "running"
    /\ taskState = "reported"
    /\ reportKind \in Reports
    /\ taskState' = IF reportKind = "valid" THEN "succeeded" ELSE "failed"
    /\ futureState' = IF reportKind = "valid" THEN "succeeded" ELSE "failed"
    /\ outstanding' = FALSE
    /\ UNCHANGED <<managerState, collectorState, reportKind>>

ManagerFails ==
    /\ managerState = "up"
    /\ managerState' = "failed"
    /\ collectorState' = "stopped"
    /\ UNCHANGED <<taskState, futureState, reportKind, outstanding>>

CollectorCleanup ==
    /\ collectorState = "stopped"
    /\ outstanding
    /\ taskState' = "failed"
    /\ futureState' = "failed"
    /\ outstanding' = FALSE
    /\ UNCHANGED <<managerState, collectorState, reportKind>>

Next ==
    \/ Submit
    \/ \E kind \in Reports : Report(kind)
    \/ Collect
    \/ ManagerFails
    \/ CollectorCleanup
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ managerState \in ManagerStates
    /\ collectorState \in CollectorStates
    /\ taskState \in TaskStates
    /\ futureState \in FutureStates
    /\ reportKind \in (Reports \cup {"none"})
    /\ outstanding \in BOOLEAN

ResultMappingSafety ==
    taskState = "succeeded" => /\ futureState = "succeeded"
                              /\ reportKind = "valid"

FailureMappingSafety ==
    taskState = "failed" => futureState = "failed"

OutstandingSafety ==
    outstanding => taskState \in {"submitted", "reported"}
                 /\ futureState = "pending"

=============================================================================
