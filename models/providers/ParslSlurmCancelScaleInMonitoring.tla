---------------------- MODULE ParslSlurmCancelScaleInMonitoring ----------------------
EXTENDS Naturals

(***************************************************************************
 * Cross-layer Slurm cancellation and BlockProviderExecutor.scale_in.
 * A successful scheduler cancellation must result in an executor terminal
 * block state and a monitoring publication, even when a requested local ID
 * is stale.  The Current provider exception aborts that propagation.
 ***************************************************************************
 *)

CONSTANT USE_FIXED
BlockStates == {"running", "scaled_in"}
Operations == {"ready", "done", "aborted"}

VARIABLES block, operation, monitoring
vars == <<block, operation, monitoring>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ block = "running"
    /\ operation = "ready"
    /\ monitoring = "none"

CancelRemote ==
    /\ operation = "ready"
    /\ operation' = IF USE_FIXED THEN "done" ELSE "aborted"
    /\ block' = IF USE_FIXED THEN "scaled_in" ELSE "running"
    /\ monitoring' = IF USE_FIXED THEN "scaled_in" ELSE "none"

Next == CancelRemote \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ block \in BlockStates
    /\ operation \in Operations
    /\ monitoring \in (BlockStates \cup {"none"})

TerminalPropagation == operation = "done" => block = "scaled_in" /\ monitoring = "scaled_in"
NoAbort == operation # "aborted"

========================================================================================
