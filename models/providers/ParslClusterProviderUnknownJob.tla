--------------------------- MODULE ParslClusterProviderUnknownJob ---------------------------
EXTENDS Naturals, FiniteSets

(***************************************************************************
 * Generic ClusterProvider.status handling for an unknown job id.
 *
 * ClusterProvider invokes the provider-specific poll and then indexes
 * ``resources[jid]`` for every requested id.  If a caller asks about an id
 * no longer present in local bookkeeping, the current method raises
 * KeyError instead of returning an explicit missing status.  USE_FIXED
 * models a total lookup that returns MISSING.
 ***************************************************************************)

CONSTANT USE_FIXED
JobStates == {"RUNNING", "MISSING", "CRASH"}

VARIABLES resources, requested, result
vars == <<resources, requested, result>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ resources = {"known"}
    /\ requested = {"unknown"}
    /\ result = "none"

Poll ==
    /\ result = "none"
    /\ IF "unknown" \in resources
          THEN result' = "RUNNING"
          ELSE IF USE_FIXED THEN result' = "MISSING" ELSE result' = "CRASH"
    /\ UNCHANGED <<resources, requested>>

Next ==
    \/ Poll
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ resources \subseteq {"known", "unknown"}
    /\ requested \subseteq {"known", "unknown"}
    /\ result \in (JobStates \cup {"none"})

UnknownJobSafety ==
    result = "MISSING" \/ result = "none"

=============================================================================
