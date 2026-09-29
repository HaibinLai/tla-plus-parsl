--------------------------- MODULE ParslHtexCoresPerWorker ---------------------------
EXTENDS Naturals

(***************************************************************************
 * HighThroughputExecutor cores_per_worker validation.
 *
 * When a provider advertises cores_per_node, the executor computes worker
 * capacity by dividing by cores_per_worker.  The current constructor lets a
 * zero value reach that division; the fixed branch rejects it at admission.
 ***************************************************************************)

CONSTANTS CORES_PER_WORKER, USE_FIXED
VARIABLE state, workerCapacity
vars == <<state, workerCapacity>>

Init ==
    /\ CORES_PER_WORKER \in 0..2
    /\ USE_FIXED \in BOOLEAN
    /\ state = "new"
    /\ workerCapacity = 0

Construct ==
    /\ state = "new"
    /\ IF USE_FIXED THEN CORES_PER_WORKER > 0 ELSE TRUE
    /\ IF CORES_PER_WORKER > 0
          THEN /\ state' = "ready"
               /\ workerCapacity' = 4 \div CORES_PER_WORKER
          ELSE /\ state' = "error"
               /\ UNCHANGED workerCapacity

Reject ==
    /\ state = "new"
    /\ USE_FIXED
    /\ CORES_PER_WORKER = 0
    /\ state' = "rejected"
    /\ UNCHANGED workerCapacity

Next == Construct \/ Reject \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in {"new", "ready", "error", "rejected"}
    /\ workerCapacity \in Nat

CapacitySafety == state = "ready" => CORES_PER_WORKER > 0
NoDivisionError == state # "error"

=============================================================================
