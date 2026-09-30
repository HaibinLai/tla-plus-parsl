--------------------------- MODULE ParslDependencyIdentityDedup ---------------------------
EXTENDS Naturals, FiniteSets

(***************************************************************************
 * Dependency collection must be identity-aware.
 *
 * DataFlowKernel gathers Futures from ordinary keyword arguments and from
 * the reserved `inputs` collection. The same Future can occur in both
 * positions (or more than once in either position). The current collection
 * path appends every traversal result, while the fixed path records each
 * Future identity once before callback registration.
 ***************************************************************************)

CONSTANTS USE_FIXED

Dependencies == {"f1"}
Sources == 1..3

VARIABLES position, gathered, dependencyCount
vars == <<position, gathered, dependencyCount>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ position = 1
    /\ gathered = {}
    /\ dependencyCount = 0

GatherAtSource(src) ==
    /\ position = src
    /\ IF USE_FIXED
       THEN IF "f1" \in gathered
            THEN /\ gathered' = gathered
                 /\ dependencyCount' = dependencyCount
            ELSE /\ gathered' = gathered \cup {"f1"}
                 /\ dependencyCount' = dependencyCount + 1
       ELSE /\ gathered' = gathered \cup {"f1"}
            /\ dependencyCount' = dependencyCount + 1
    /\ position' = src + 1

Next ==
    \/ \E src \in Sources : GatherAtSource(src)
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ position \in 1..4
    /\ gathered \subseteq Dependencies
    /\ dependencyCount \in 0..3

NoDuplicateDependency == dependencyCount <= Cardinality(gathered)

=============================================================================
