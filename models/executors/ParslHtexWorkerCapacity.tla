------------------------- MODULE ParslHtexWorkerCapacity -------------------------
EXTENDS Naturals

(***************************************************************************
 * HighThroughputExecutor worker-capacity calculation.
 *
 * HighThroughputExecutor derives workers per node from the provider's CPU and
 * memory hints, the configured maximum, and (when present) accelerator count.
 * This small model keeps those values finite while preserving the ordering
 * contract: no resource can be oversubscribed by the computed worker count.
 ***************************************************************************)

CONSTANTS MAX_WORKERS, CORES_NODE, MEM_NODE, CORES_PER_WORKER,
          MEM_PER_WORKER, ACCELERATORS

VARIABLES state, workerCapacity
vars == <<state, workerCapacity>>

CpuSlots == CORES_NODE \div CORES_PER_WORKER
MemSlots == IF MEM_PER_WORKER > 0
               THEN MEM_NODE \div MEM_PER_WORKER
               ELSE MAX_WORKERS
AccelSlots == IF ACCELERATORS > 0
                 THEN ACCELERATORS
                 ELSE MAX_WORKERS
Min2(a, b) == IF a < b THEN a ELSE b
Min3(a, b, c) == Min2(Min2(a, b), c)
DerivedCapacity == Min3(MAX_WORKERS, CpuSlots, Min2(MemSlots, AccelSlots))

Init ==
    /\ MAX_WORKERS \in Nat
    /\ CORES_NODE \in Nat
    /\ MEM_NODE \in Nat
    /\ CORES_PER_WORKER \in Nat \ {0}
    /\ MEM_PER_WORKER \in Nat
    /\ ACCELERATORS \in Nat
    /\ state = "new"
    /\ workerCapacity = 0

Construct ==
    /\ state = "new"
    /\ workerCapacity' = DerivedCapacity
    /\ state' = "ready"

Next == Construct \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in {"new", "ready"}
    /\ workerCapacity \in Nat

CapacitySafety ==
    state = "ready" =>
        /\ workerCapacity <= MAX_WORKERS
        /\ workerCapacity * CORES_PER_WORKER <= CORES_NODE
        /\ workerCapacity * MEM_PER_WORKER <= MEM_NODE
        /\ (ACCELERATORS > 0 => workerCapacity <= ACCELERATORS)

=============================================================================
