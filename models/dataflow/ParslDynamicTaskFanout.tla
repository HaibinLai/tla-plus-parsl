--------------------------- MODULE ParslDynamicTaskFanout ---------------------------
EXTENDS Naturals, FiniteSets

(***************************************************************************
 * A bounded dynamic fan-out DAG.
 *
 * A parent app creates two logical children only after its Future resolves.
 * C1 depends on the parent; C2 depends on both the parent and C1.  Children
 * have a bounded retry budget, so logical task state is kept separate from
 * the physical attempt counter.
 ***************************************************************************)

CONSTANT MAX_RETRIES

Children == {"C1", "C2"}
AllNodes == Children \cup {"parent"}
NodeStates == {"pending", "blocked", "running", "succeeded", "failed", "absent"}
FutureStates == {"unresolved", "resolved", "rejected"}

Deps(c) == IF c = "C1" THEN {"parent"} ELSE {"parent", "C1"}

VARIABLES parentState, childState, parentFuture, childFuture,
          attempts, created
vars == <<parentState, childState, parentFuture, childFuture, attempts, created>>

Init ==
    /\ MAX_RETRIES >= 0
    /\ parentState = "pending"
    /\ childState = [c \in Children |-> "absent"]
    /\ parentFuture = "unresolved"
    /\ childFuture = [c \in Children |-> "unresolved"]
    /\ attempts = [c \in Children |-> 0]
    /\ created = FALSE

StartParent ==
    /\ parentState = "pending"
    /\ parentState' = "running"
    /\ UNCHANGED <<childState, parentFuture, childFuture, attempts, created>>

CompleteParent ==
    /\ parentState = "running"
    /\ parentState' = "succeeded"
    /\ parentFuture' = "resolved"
    /\ UNCHANGED <<childState, childFuture, attempts, created>>

FailParent ==
    /\ parentState = "running"
    /\ parentState' = "failed"
    /\ parentFuture' = "rejected"
    /\ UNCHANGED <<childState, childFuture, attempts, created>>

CreateChildren ==
    /\ parentState = "succeeded"
    /\ parentFuture = "resolved"
    /\ ~created
    /\ childState' = [c \in Children |-> "blocked"]
    /\ created' = TRUE
    /\ UNCHANGED <<parentState, parentFuture, childFuture, attempts>>

Ready(c) ==
    /\ c \in Children
    /\ parentFuture = "resolved"
    /\ \A d \in Deps(c) \cap Children : childFuture[d] = "resolved"

ReleaseChild(c) ==
    /\ c \in Children
    /\ childState[c] = "blocked"
    /\ Ready(c)
    /\ childState' = [childState EXCEPT ![c] = "pending"]
    /\ UNCHANGED <<parentState, parentFuture, childFuture, attempts, created>>

StartChild(c) ==
    /\ c \in Children
    /\ childState[c] = "pending"
    /\ Ready(c)
    /\ childState' = [childState EXCEPT ![c] = "running"]
    /\ UNCHANGED <<parentState, parentFuture, childFuture, attempts, created>>

CompleteChild(c) ==
    /\ c \in Children
    /\ childState[c] = "running"
    /\ childState' = [childState EXCEPT ![c] = "succeeded"]
    /\ childFuture' = [childFuture EXCEPT ![c] = "resolved"]
    /\ UNCHANGED <<parentState, parentFuture, attempts, created>>

RetryChild(c) ==
    /\ c \in Children
    /\ childState[c] = "running"
    /\ childFuture[c] = "unresolved"
    /\ attempts[c] < MAX_RETRIES
    /\ attempts' = [attempts EXCEPT ![c] = @ + 1]
    /\ childState' = [childState EXCEPT ![c] = "pending"]
    /\ UNCHANGED <<parentState, parentFuture, childFuture, created>>

FailChild(c) ==
    /\ c \in Children
    /\ childState[c] = "running"
    /\ childFuture[c] = "unresolved"
    /\ attempts[c] = MAX_RETRIES
    /\ childState' = [childState EXCEPT ![c] = "failed"]
    /\ childFuture' = [childFuture EXCEPT ![c] = "rejected"]
    /\ UNCHANGED <<parentState, parentFuture, attempts, created>>

Next ==
    \/ StartParent
    \/ CompleteParent
    \/ FailParent
    \/ CreateChildren
    \/ \E c \in Children : ReleaseChild(c) \/ StartChild(c)
    \/ \E c \in Children : CompleteChild(c) \/ RetryChild(c) \/ FailChild(c)
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ parentState \in NodeStates
    /\ childState \in [Children -> NodeStates]
    /\ parentFuture \in FutureStates
    /\ childFuture \in [Children -> FutureStates]
    /\ attempts \in [Children -> 0..MAX_RETRIES]
    /\ created \in BOOLEAN

CreationSafety ==
    created => /\ parentState = "succeeded"
               /\ parentFuture = "resolved"
               /\ \A c \in Children : childState[c] # "absent"

DependencySafety ==
    \A c \in Children : childState[c] \in {"pending", "running", "succeeded"}
        => Ready(c)

FutureConsistency ==
    /\ parentFuture = "resolved" => parentState = "succeeded"
    /\ parentFuture = "rejected" => parentState = "failed"
    /\ \A c \in Children :
        /\ childFuture[c] = "resolved" => childState[c] = "succeeded"
        /\ childFuture[c] = "rejected" => childState[c] = "failed"

RetryBoundSafety ==
    \A c \in Children : attempts[c] <= MAX_RETRIES

TerminalStability ==
    /\ parentFuture = "resolved" => parentState = "succeeded"
    /\ \A c \in Children :
        /\ childFuture[c] = "resolved" => childState[c] = "succeeded"
        /\ childFuture[c] = "rejected" => childState[c] = "failed"

=============================================================================
