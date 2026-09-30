--------------------------- MODULE ParslDynamicTaskCreation ---------------------------
EXTENDS Naturals

(***************************************************************************
 * A bounded dynamic-task dataflow.
 *
 * A running parent app creates a child task only after its own Future has
 * resolved. The child is initially blocked on that Future, then becomes
 * runnable and propagates its own result independently.
 **************************************************************************)

ParentStates == {"pending", "running", "succeeded", "failed"}
ChildStates == {"absent", "blocked", "pending", "running", "succeeded", "failed"}
FutureStates == {"unresolved", "resolved", "rejected"}

VARIABLES parentState, childState, parentFuture, childFuture
vars == <<parentState, childState, parentFuture, childFuture>>

Init ==
    /\ parentState = "pending"
    /\ childState = "absent"
    /\ parentFuture = "unresolved"
    /\ childFuture = "unresolved"

StartParent ==
    /\ parentState = "pending"
    /\ parentState' = "running"
    /\ UNCHANGED <<childState, parentFuture, childFuture>>

CompleteParent ==
    /\ parentState = "running"
    /\ parentState' = "succeeded"
    /\ parentFuture' = "resolved"
    /\ UNCHANGED <<childState, childFuture>>

FailParent ==
    /\ parentState = "running"
    /\ parentState' = "failed"
    /\ parentFuture' = "rejected"
    /\ UNCHANGED <<childState, childFuture>>

CreateChild ==
    /\ parentState = "succeeded"
    /\ parentFuture = "resolved"
    /\ childState = "absent"
    /\ childState' = "blocked"
    /\ UNCHANGED <<parentState, parentFuture, childFuture>>

ReleaseChild ==
    /\ childState = "blocked"
    /\ parentFuture = "resolved"
    /\ childState' = "pending"
    /\ UNCHANGED <<parentState, parentFuture, childFuture>>

StartChild ==
    /\ childState = "pending"
    /\ parentFuture = "resolved"
    /\ childState' = "running"
    /\ UNCHANGED <<parentState, parentFuture, childFuture>>

CompleteChild ==
    /\ childState = "running"
    /\ childState' = "succeeded"
    /\ childFuture' = "resolved"
    /\ UNCHANGED <<parentState, parentFuture>>

FailChild ==
    /\ childState = "running"
    /\ childState' = "failed"
    /\ childFuture' = "rejected"
    /\ UNCHANGED <<parentState, parentFuture>>

Next ==
    \/ StartParent
    \/ CompleteParent
    \/ FailParent
    \/ CreateChild
    \/ ReleaseChild
    \/ StartChild
    \/ CompleteChild
    \/ FailChild
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ parentState \in ParentStates
    /\ childState \in ChildStates
    /\ parentFuture \in FutureStates
    /\ childFuture \in FutureStates

DynamicCreationSafety ==
    childState # "absent" => parentState = "succeeded"

DependencySafety ==
    childState \in {"pending", "running", "succeeded"}
        => parentFuture = "resolved"

FutureConsistency ==
    /\ parentFuture = "resolved" => parentState = "succeeded"
    /\ parentFuture = "rejected" => parentState = "failed"
    /\ childFuture = "resolved" => childState = "succeeded"
    /\ childFuture = "rejected" => childState = "failed"

TerminalStability ==
    /\ parentFuture = "resolved" => parentState = "succeeded"
    /\ childFuture = "resolved" => childState = "succeeded"

=============================================================================
SPECIFICATION Spec

INVARIANTS
    TypeOK
    DynamicCreationSafety
    DependencySafety
    FutureConsistency
    TerminalStability
