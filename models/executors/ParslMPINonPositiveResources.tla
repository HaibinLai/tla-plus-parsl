--------------------------- MODULE ParslMPINonPositiveResources ---------------------------
EXTENDS Naturals, Integers

(***************************************************************************
 * MPIExecutor resource admission.
 *
 * mpi_prefix_composer.validate_resource_spec checks allowed field names and
 * derives missing values, but the current helper accepts zero or negative
 * node/rank counts.  Those values can reach an MPI launcher.  USE_FIXED
 * represents rejecting non-positive resource counts before derivation.
 *************************************************************************** *)

CONSTANTS USE_FIXED, NUM_NODES, NUM_RANKS, RANKS_PER_NODE

Phases == {"configured", "rejected", "accepted", "derived"}
Values == {"unset", "positive", "nonpositive"}

VARIABLES phase, derivedRanksPerNode
vars == <<phase, derivedRanksPerNode>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ NUM_NODES \in Int
    /\ NUM_RANKS \in Int
    /\ RANKS_PER_NODE \in Int
    /\ phase = "configured"
    /\ derivedRanksPerNode = "unset"

Validate ==
    /\ phase = "configured"
    /\ IF USE_FIXED /\ (NUM_NODES <= 0 \/ NUM_RANKS <= 0 \/ RANKS_PER_NODE <= 0)
          THEN phase' = "rejected"
          ELSE phase' = "accepted"
    /\ UNCHANGED derivedRanksPerNode

Derive ==
    /\ phase = "accepted"
    /\ phase' = "derived"
    /\ derivedRanksPerNode' =
          IF NUM_NODES > 0 /\ NUM_RANKS > 0 /\ RANKS_PER_NODE > 0
             THEN "positive" ELSE "nonpositive"

Next ==
    \/ Validate
    \/ Derive
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ phase \in Phases
    /\ derivedRanksPerNode \in Values

PositiveResourceSafety ==
    phase \in {"accepted", "derived"}
        => NUM_NODES > 0 /\ NUM_RANKS > 0 /\ RANKS_PER_NODE > 0

=============================================================================
