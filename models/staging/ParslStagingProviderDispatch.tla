--------------------------- MODULE ParslStagingProviderDispatch ---------------------------
EXTENDS Naturals

(***************************************************************************
 * DataManager provider dispatch.
 *
 * DataManager scans storage_access in order and invokes only the first
 * provider whose can_stage_* predicate is true.  A provider result of NONE
 * means that the provider handled the file without creating a wait Future;
 * it does not cause a second provider to be tried.  A Future result creates a
 * DataFuture dependency which must complete before the task can run.
 *************************************************************************** *)

CONSTANTS PROVIDER_COUNT, CAPABLE, FUTURE_PROVIDERS

ResultKinds == {"none", "future"}
States == {"new", "selected", "ready", "running", "failed"}

VARIABLES state, selected, dependency, task
vars == <<state, selected, dependency, task>>

Init ==
    /\ PROVIDER_COUNT > 0
    /\ CAPABLE \subseteq 1..PROVIDER_COUNT
    /\ FUTURE_PROVIDERS \subseteq CAPABLE
    /\ state = "new"
    /\ selected = 0
    /\ dependency = 0
    /\ task = "blocked"

FirstCapable == CHOOSE i \in 1..PROVIDER_COUNT :
    i \in CAPABLE /\ \A j \in 1..i - 1 : j \notin CAPABLE

SelectProvider ==
    /\ state = "new"
    /\ \E i \in 1..PROVIDER_COUNT :
        i \in CAPABLE /\ i = FirstCapable
    /\ selected' = FirstCapable
    /\ dependency' = IF selected' \in FUTURE_PROVIDERS THEN 1 ELSE 0
    /\ state' = "selected"
    /\ UNCHANGED task

NoProvider ==
    /\ state = "new"
    /\ \A i \in 1..PROVIDER_COUNT : i \notin CAPABLE
    /\ state' = "failed"
    /\ selected' = 0
    /\ dependency' = 0
    /\ UNCHANGED task

CompleteDependency ==
    /\ state = "selected"
    /\ dependency = 1
    /\ dependency' = 0
    /\ state' = "ready"
    /\ UNCHANGED <<selected, task>>

RunWithoutWait ==
    /\ state = "selected"
    /\ dependency = 0
    /\ state' = "running"
    /\ task' = "running"
    /\ UNCHANGED <<selected, dependency>>

RunAfterDependency ==
    /\ state = "ready"
    /\ state' = "running"
    /\ task' = "running"
    /\ UNCHANGED <<selected, dependency>>

Next ==
    \/ SelectProvider
    \/ NoProvider
    \/ CompleteDependency
    \/ RunWithoutWait
    \/ RunAfterDependency
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in States
    /\ selected \in 0..PROVIDER_COUNT
    /\ dependency \in 0..1
    /\ task \in {"blocked", "running"}

FirstMatchSafety ==
    state = "selected" => selected = FirstCapable

NoPrematureRun ==
    task = "running" => state = "running"

DependencyGateSafety ==
    state = "selected" /\ dependency = 1 => task = "blocked"

=============================================================================
