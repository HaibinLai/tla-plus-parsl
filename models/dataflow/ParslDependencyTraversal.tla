--------------------------- MODULE ParslDependencyTraversal ---------------------------
EXTENDS Naturals, Sequences, FiniteSets

(***************************************************************************
 * Bounded model of Parsl's dependency resolver.
 *
 * The real resolver has two policies: the default shallow policy recognizes
 * a Future only when it is passed directly, while the deep policy recursively
 * traverses lists, tuples, sets, and dictionaries.  This model keeps one
 * Future and one container shape so TLC can expose the consequence of using
 * the wrong policy: a nested Future can reach the worker before it resolves.
 ***************************************************************************)

CONSTANTS MODE, SHAPE

Modes == {"shallow", "deep"}
Shapes == {"direct", "list", "dictValue", "dictKey", "tuple", "set"}
FutureStates == {"pending", "succeeded", "failed"}
TaskStates == {"new", "ready", "running", "succeeded", "failed"}

VARIABLES futureState, gathered, taskState, workerValue

vars == <<futureState, gathered, taskState, workerValue>>

Init ==
    /\ MODE \in Modes
    /\ SHAPE \in Shapes
    /\ futureState = "pending"
    /\ gathered = FALSE
    /\ taskState = "new"
    /\ workerValue = "not-called"

ResolverFindsFuture ==
    IF SHAPE = "direct" THEN TRUE
    ELSE MODE = "deep"

GatherDependencies ==
    /\ taskState = "new"
    /\ gathered' = ResolverFindsFuture
    /\ taskState' = "ready"
    /\ UNCHANGED <<futureState, workerValue>>

ResolveFuture ==
    /\ futureState = "pending"
    /\ futureState' = "succeeded"
    /\ UNCHANGED <<gathered, taskState, workerValue>>

RejectFuture ==
    /\ futureState = "pending"
    /\ futureState' = "failed"
    /\ UNCHANGED <<gathered, taskState, workerValue>>

LaunchWhenReady ==
    /\ taskState = "ready"
    /\ (gathered => futureState # "pending")
    /\ taskState' = "running"
    /\ UNCHANGED <<futureState, gathered, workerValue>>

RunWorker ==
    /\ taskState = "running"
    /\ IF futureState = "failed" THEN
           /\ taskState' = "failed"
           /\ workerValue' = "dependency-error"
       ELSE IF gathered THEN
           /\ taskState' = "succeeded"
           /\ workerValue' = "unwrapped-value"
       ELSE IF SHAPE = "direct" THEN
           /\ taskState' = "succeeded"
           /\ workerValue' = "unwrapped-value"
       ELSE
           /\ taskState' = "failed"
           /\ workerValue' = "nested-future-object"
    /\ UNCHANGED <<futureState, gathered>>

Next ==
    \/ GatherDependencies
    \/ ResolveFuture
    \/ RejectFuture
    \/ LaunchWhenReady
    \/ RunWorker
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ futureState \in FutureStates
    /\ gathered \in BOOLEAN
    /\ taskState \in TaskStates
    /\ workerValue \in {"not-called", "unwrapped-value", "dependency-error",
                         "nested-future-object"}

DependencySafety ==
    /\ taskState = "running" => (gathered => futureState # "pending")
    /\ taskState = "succeeded" => futureState # "pending"

NoNestedFutureLeak ==
    workerValue # "nested-future-object"

TerminalStability ==
    taskState = "succeeded" => [] (taskState = "succeeded")

=============================================================================
