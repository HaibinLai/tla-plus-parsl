--------------------------- MODULE ParslScaleOutFailureMonitoring ---------------------------
EXTENDS Naturals

(***************************************************************************
 * BlockProviderExecutor.scale_out_facade provisioning failure reporting.
 *
 * A provider submission failure is retained in _status as a FAILED block.
 * The current implementation only adds successful PENDING blocks to the
 * monitoring delta, so the failed block can be invisible to monitoring.
 ***************************************************************************)

CONSTANTS BLOCKS, SUBMIT_OK, USE_FIXED

BlockStates == {"none", "pending", "failed"}
VARIABLES blockState, monitoring
vars == <<blockState, monitoring>>

Init ==
    /\ BLOCKS \in Nat
    /\ BLOCKS > 0
    /\ SUBMIT_OK \subseteq 1..BLOCKS
    /\ USE_FIXED \in BOOLEAN
    /\ blockState = [i \in 1..BLOCKS |-> "none"]
    /\ monitoring = {}

ScaleOut(i) ==
    /\ i \in 1..BLOCKS
    /\ blockState[i] = "none"
    /\ IF i \in SUBMIT_OK THEN
           /\ blockState' = [blockState EXCEPT ![i] = "pending"]
           /\ monitoring' = monitoring \cup {i}
       ELSE
           /\ blockState' = [blockState EXCEPT ![i] = "failed"]
           /\ monitoring' = IF USE_FIXED THEN monitoring \cup {i} ELSE monitoring

Next ==
    \/ \E i \in 1..BLOCKS : ScaleOut(i)
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ BLOCKS \in Nat
    /\ BLOCKS > 0
    /\ SUBMIT_OK \subseteq 1..BLOCKS
    /\ USE_FIXED \in BOOLEAN
    /\ blockState \in [1..BLOCKS -> BlockStates]
    /\ monitoring \subseteq 1..BLOCKS

FailureReportSafety ==
    \A i \in 1..BLOCKS :
        blockState[i] = "failed" => i \in monitoring

=============================================================================
