--------------------------- MODULE ParslScaleOutFailureMonitoring ---------------------------
EXTENDS Naturals

(***************************************************************************
 * BlockProviderExecutor.scale_out_facade provisioning failure reporting.
 *
 * A provider submission failure is retained in _status as a FAILED block.
 * The current implementation only adds successful PENDING blocks to the
 * monitoring delta, so the failed block can be invisible to monitoring.
 ***************************************************************************)

CONSTANTS SUBMIT_OK, USE_FIXED

BlockStates == {"none", "pending", "failed"}
VARIABLES blockState, monitoring
vars == <<blockState, monitoring>>

Init ==
    /\ SUBMIT_OK \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ blockState = "none"
    /\ monitoring = {}

ScaleOut ==
    /\ blockState = "none"
    /\ IF SUBMIT_OK THEN
           /\ blockState' = "pending"
           /\ monitoring' = {"pending"}
       ELSE
           /\ blockState' = "failed"
           /\ monitoring' = IF USE_FIXED THEN {"failed"} ELSE {}

Next ==
    \/ ScaleOut
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ SUBMIT_OK \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ blockState \in BlockStates
    /\ monitoring \subseteq {"pending", "failed"}

FailureReportSafety ==
    blockState = "failed" => "failed" \in monitoring

=============================================================================
