--------------------------- MODULE ParslClusterStatusUnknown ---------------------------
EXTENDS Naturals

(***************************************************************************
 * ClusterProvider.status with a stale local job identifier.
 *
 * ClusterProvider refreshes provider state and then projects the requested
 * identifiers through its local resources map.  The current projection uses
 * an unconditional lookup, so a job removed by an earlier poll raises
 * KeyError and aborts the whole status request.  The fixed branch preserves
 * response cardinality by returning an explicit UNKNOWN observation.
 ***************************************************************************)

CONSTANT USE_FIXED

ResourceStates == {"running"}
ObservedStates == {"running", "unknown", "error"}
VARIABLES resourceState, observed, request
vars == <<resourceState, observed, request>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ resourceState = "running"
    /\ observed = "none"
    /\ request = "pending"

StatusKnown ==
    /\ request = "pending"
    /\ observed' = "running"
    /\ request' = "done"
    /\ UNCHANGED resourceState

StatusStale ==
    /\ request = "pending"
    /\ observed' = IF USE_FIXED THEN "unknown" ELSE "error"
    /\ request' = "done"
    /\ UNCHANGED resourceState

Next == StatusKnown \/ StatusStale \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ resourceState \in ResourceStates
    /\ observed \in (ObservedStates \cup {"none"})
    /\ request \in {"pending", "done"}

NoProjectionCrash == observed # "error"
ResponseCardinality == request = "done" => observed \in {"running", "unknown"}

=============================================================================
