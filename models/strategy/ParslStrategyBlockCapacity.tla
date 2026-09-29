--------------------------- MODULE ParslStrategyBlockCapacity ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Strategy capacity validation.
 *
 * Strategy._general_strategy computes excess_blocks by dividing by
 * workers_per_node * provider.nodes_per_block.  A zero nodes_per_block is
 * accepted until the first overloaded poll, where the current path raises
 * ZeroDivisionError.  USE_FIXED represents rejecting non-positive capacity
 * when strategy configuration is admitted.
 *************************************************************************** *)

CONSTANTS NODES_PER_BLOCK, USE_FIXED
VARIABLES state, scaleRequestIssued
vars == <<state, scaleRequestIssued>>

Init ==
    /\ NODES_PER_BLOCK \in 0..1
    /\ USE_FIXED \in BOOLEAN
    /\ state = "configured"
    /\ scaleRequestIssued = FALSE

AcceptConfiguration ==
    /\ state = "configured"
    /\ IF USE_FIXED THEN NODES_PER_BLOCK > 0 ELSE TRUE
    /\ state' = "polling"
    /\ UNCHANGED scaleRequestIssued

RejectConfiguration ==
    /\ state = "configured"
    /\ USE_FIXED
    /\ NODES_PER_BLOCK = 0
    /\ state' = "rejected"
    /\ UNCHANGED scaleRequestIssued

ComputeScaleRequest ==
    /\ state = "polling"
    /\ NODES_PER_BLOCK > 0
    /\ state' = "scaled"
    /\ scaleRequestIssued' = TRUE

DivisionFailure ==
    /\ state = "polling"
    /\ NODES_PER_BLOCK = 0
    /\ state' = "crashed"
    /\ UNCHANGED scaleRequestIssued

Next ==
    \/ AcceptConfiguration
    \/ RejectConfiguration
    \/ ComputeScaleRequest
    \/ DivisionFailure
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in {"configured", "polling", "scaled", "rejected", "crashed"}
    /\ scaleRequestIssued \in BOOLEAN

NoStrategyCrash == state # "crashed"
ScaleRequestSafety == scaleRequestIssued => NODES_PER_BLOCK > 0
=============================================================================
