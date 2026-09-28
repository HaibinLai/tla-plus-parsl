--------------------------- MODULE ParslHtexForceScaleIn ---------------------------
EXTENDS Naturals

(***************************************************************************
 * HighThroughputExecutor.scale_in(blocks, max_idletime=None) deliberately
 * permits forced scale-in.  The implementation selects blocks even when
 * their managers report active tasks; cancelling the provider job then loses
 * that worker context and relies on the normal worker-loss/retry path.
 * USE_FIXED models the safer idle-only policy for comparison.
 *************************************************************************** *)

CONSTANT USE_FIXED

VARIABLES blockState, taskCount, phase
vars == <<blockState, taskCount, phase>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ blockState = "active"
    /\ taskCount = 1
    /\ phase = "running"

ScaleIn ==
    /\ phase = "running"
    /\ blockState = "active"
    /\ IF USE_FIXED /\ taskCount > 0
          THEN phase' = "protected"
          ELSE phase' = "scaled-in"
    /\ blockState' = IF USE_FIXED /\ taskCount > 0 THEN "active" ELSE "cancelled"
    /\ UNCHANGED taskCount

WorkerLossRecovery ==
    /\ phase = "scaled-in"
    /\ phase' = "retrying"
    /\ blockState' = "active"
    /\ UNCHANGED taskCount

Done ==
    /\ phase \in {"protected", "retrying"}
    /\ UNCHANGED vars

Next == ScaleIn \/ WorkerLossRecovery \/ Done
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ blockState \in {"active", "cancelled"}
    /\ taskCount \in Nat
    /\ phase \in {"running", "scaled-in", "protected", "retrying"}

BusyScaleInSafety ==
    taskCount > 0 => phase # "scaled-in"

=============================================================================
