--------------------------- MODULE ParslMPINonDivisibleRanks ---------------------------
EXTENDS Naturals, Integers

(***************************************************************************
 * MPIExecutor derives ranks_per_node when num_nodes and num_ranks are given.
 * The current helper performs true division and accepts a non-integral value,
 * which later appears in an MPI launcher option such as ``-ppn 2.5``.
 * USE_FIXED rejects a non-divisible rank allocation before launch.
 *************************************************************************** *)

CONSTANT USE_FIXED

VARIABLES phase, numNodes, numRanks, ranksPerNode
vars == <<phase, numNodes, numRanks, ranksPerNode>>
RankValues == {"zero", "integral", "fractional"}

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ phase = "configured"
    /\ numNodes = 2
    /\ numRanks = 5
    /\ ranksPerNode = "zero"

Validate ==
    /\ phase = "configured"
    /\ IF USE_FIXED /\ numRanks % numNodes # 0
          THEN phase' = "rejected"
          ELSE phase' = "accepted"
    /\ UNCHANGED <<numNodes, numRanks, ranksPerNode>>

Derive ==
    /\ phase = "accepted"
    /\ ranksPerNode' = IF numRanks % numNodes = 0 THEN "integral" ELSE "fractional"
    /\ phase' = "derived"
    /\ UNCHANGED <<numNodes, numRanks>>

Launch ==
    /\ phase = "derived"
    /\ phase' = "launched"
    /\ UNCHANGED <<numNodes, numRanks, ranksPerNode>>

Done ==
    /\ phase \in {"rejected", "launched"}
    /\ UNCHANGED vars

Next == Validate \/ Derive \/ Launch \/ Done
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ phase \in {"configured", "accepted", "rejected", "derived", "launched"}
    /\ numNodes \in Nat
    /\ numRanks \in Nat
    /\ ranksPerNode \in RankValues

IntegralRanksSafety ==
    phase \in {"derived", "launched"} => ranksPerNode = "integral"

=============================================================================
