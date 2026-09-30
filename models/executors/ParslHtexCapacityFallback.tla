------------------------ MODULE ParslHtexCapacityFallback ------------------------
EXTENDS Naturals, FiniteSets

(***************************************************************************
 * HTEX worker-capacity fallback when a provider advertises no hints.
 *
 * HighThroughputExecutor starts with an unbounded max-worker value.  If the
 * provider supplies no CPU or memory limits and no accelerators are listed,
 * the constructor normalizes that unbounded value to one worker per node as a
 * conservative best guess.
 ***************************************************************************)

VARIABLES state, workerCapacity
vars == <<state, workerCapacity>>

Init ==
    /\ state = "new"
    /\ workerCapacity = 0

Construct ==
    /\ state = "new"
    /\ state' = "ready"
    /\ workerCapacity' = 1

Next == Construct \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in {"new", "ready"}
    /\ workerCapacity \in Nat

FallbackSafety == state = "ready" => workerCapacity = 1

=============================================================================
