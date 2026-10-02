--------------------------- MODULE ParslWorkQueueFailureFanout ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Failure fan-out for WorkQueueExecutor's result collector.
 * The live task dictionary is unsafe while Future callbacks run; a snapshot
 * preserves failure delivery to every pending logical task.
 ***************************************************************************)

CONSTANT USE_FIXED
FutureStates == {"pending", "failed"}

VARIABLES first, second, mapState, collectorState
vars == <<first, second, mapState, collectorState>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ first = "pending"
    /\ second = "pending"
    /\ mapState = "two_entries"
    /\ collectorState = "running"

FailFirst ==
    /\ collectorState = "running"
    /\ first = "pending"
    /\ first' = "failed"
    /\ mapState' = IF USE_FIXED THEN "snapshot" ELSE "mutated"
    /\ collectorState' = IF USE_FIXED THEN "running" ELSE "stopped"
    /\ UNCHANGED second

FailSecond ==
    /\ collectorState = "running"
    /\ mapState = "snapshot"
    /\ second = "pending"
    /\ second' = "failed"
    /\ UNCHANGED <<first, mapState, collectorState>>

Next == FailFirst \/ FailSecond \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ first \in FutureStates
    /\ second \in FutureStates
    /\ mapState \in {"two_entries", "snapshot", "mutated"}
    /\ collectorState \in {"running", "stopped"}

FanoutSafety == collectorState = "stopped" => second = "failed"

=========================================================================================
