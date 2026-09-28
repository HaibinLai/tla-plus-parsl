--------------------------- MODULE ParslMPISpec ---------------------------
EXTENDS Naturals, Integers, FiniteSets

(***************************************************************************
 * A focused MPIExecutor resource-specification model.
 *
 * The current MPI validation accepts the keys ranks_per_node, num_nodes,
 * num_ranks, and launcher_options.  If num_nodes is present, it derives one
 * missing rank field.  This small model makes the validation/derivation
 * boundary executable and separates it from MPI process execution.
 *
 * USE_FIXED represents a candidate hardening: reject non-positive num_nodes
 * before deriving ranks_per_node.  With USE_FIXED=FALSE, the model preserves
 * the current validation shape and exposes the zero-node derivation error.
 ***************************************************************************)

CONSTANT USE_FIXED

LEGAL_KEYS == {"ranks_per_node", "num_nodes", "num_ranks", "launcher_options"}
PHASES == {"new", "rejected", "accepted", "running", "completed", "failed"}

VARIABLES specKind, keys, numNodes, ranksPerNode, numRanks,
          phase, launchError

vars == <<specKind, keys, numNodes, ranksPerNode, numRanks,
          phase, launchError>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ specKind = "none"
    /\ keys = {}
    /\ numNodes = -1
    /\ ranksPerNode = -1
    /\ numRanks = -1
    /\ phase = "new"
    /\ launchError = FALSE

Configure(kind) ==
    /\ specKind = "none"
    /\ kind \in {"empty", "zero_nodes", "valid"}
    /\ specKind' = kind
    /\ keys' =
          CASE kind = "empty" -> {}
            [] kind = "zero_nodes" -> {"num_nodes", "num_ranks"}
            [] kind = "valid" -> {"num_nodes", "ranks_per_node"}
    /\ numNodes' =
          CASE kind = "empty" -> -1
            [] OTHER -> 2 - (IF kind = "zero_nodes" THEN 2 ELSE 0)
    /\ ranksPerNode' =
          CASE kind = "valid" -> 2
            [] OTHER -> -1
    /\ numRanks' =
          CASE kind = "zero_nodes" -> 1
            [] OTHER -> -1
    /\ UNCHANGED <<phase, launchError>>

Validate ==
    /\ specKind # "none"
    /\ phase = "new"
    /\ IF keys = {} \/ ~(keys \subseteq LEGAL_KEYS)
          \/ (USE_FIXED /\ "num_nodes" \in keys /\ numNodes <= 0)
       THEN phase' = "rejected"
       ELSE phase' = "accepted"
    /\ UNCHANGED <<specKind, keys, numNodes, ranksPerNode, numRanks,
                    launchError>>

DeriveRanks ==
    /\ phase = "accepted"
    /\ "num_nodes" \in keys
    /\ numNodes # 0
    /\ IF ranksPerNode = -1 /\ numRanks # -1
          THEN ranksPerNode' = numRanks \div numNodes
          ELSE ranksPerNode' = ranksPerNode
    /\ IF numRanks = -1 /\ ranksPerNode # -1
          THEN numRanks' = numNodes * ranksPerNode
          ELSE numRanks' = numRanks
    /\ UNCHANGED <<specKind, keys, numNodes, phase, launchError>>

ZeroNodeDerivationError ==
    /\ phase = "accepted"
    /\ "num_nodes" \in keys
    /\ numNodes = 0
    /\ ranksPerNode = -1
    /\ numRanks # -1
    /\ launchError' = TRUE
    /\ phase' = "failed"
    /\ UNCHANGED <<specKind, keys, numNodes, ranksPerNode, numRanks>>

Launch ==
    /\ phase = "accepted"
    /\ numNodes > 0
    /\ ranksPerNode > 0
    /\ numRanks > 0
    /\ phase' = "running"
    /\ UNCHANGED <<specKind, keys, numNodes, ranksPerNode, numRanks,
                    launchError>>

Complete ==
    /\ phase = "running"
    /\ phase' = "completed"
    /\ UNCHANGED <<specKind, keys, numNodes, ranksPerNode, numRanks,
                    launchError>>

Next ==
    \/ \E kind \in {"empty", "zero_nodes", "valid"} : Configure(kind)
    \/ Validate
    \/ DeriveRanks
    \/ ZeroNodeDerivationError
    \/ Launch
    \/ Complete
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ specKind \in {"none", "empty", "zero_nodes", "valid"}
    /\ keys \subseteq LEGAL_KEYS
    /\ numNodes \in -1..2
    /\ ranksPerNode \in -1..4
    /\ numRanks \in -1..4
    /\ phase \in PHASES
    /\ launchError \in BOOLEAN

ValidationSafety ==
    phase = "rejected" => keys = {} \/ ~(keys \subseteq LEGAL_KEYS)
                           \/ (USE_FIXED /\ "num_nodes" \in keys /\ numNodes <= 0)

NoLaunchError ==
    ~launchError

TerminalStability ==
    phase \in {"completed", "rejected", "failed"} => phase' = phase

=============================================================================
