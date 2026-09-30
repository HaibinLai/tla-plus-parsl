--------------------------- MODULE ParslHtexResultDecodeContinuation ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Result decode failure must not abort later independent frames in a batch.
 *
 * A batch contains a corrupt result for task A followed by a valid result for
 * task B.  The current result worker lets the first decode exception escape;
 * the fixed branch fails A explicitly and continues to consume B.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES taskA, taskB, workerAlive, corruptSeen, validSeen
vars == <<taskA, taskB, workerAlive, corruptSeen, validSeen>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ taskA = "pending"
    /\ taskB = "pending"
    /\ workerAlive = TRUE
    /\ corruptSeen = FALSE
    /\ validSeen = FALSE

DecodeCorruptA ==
    /\ workerAlive
    /\ ~corruptSeen
    /\ corruptSeen' = TRUE
    /\ IF USE_FIXED
          THEN /\ taskA' = "failed"
               /\ workerAlive' = TRUE
          ELSE /\ taskA' = "pending"
               /\ workerAlive' = FALSE
    /\ UNCHANGED <<taskB, validSeen>>

DecodeValidB ==
    /\ workerAlive
    /\ corruptSeen
    /\ ~validSeen
    /\ validSeen' = TRUE
    /\ taskB' = "succeeded"
    /\ UNCHANGED <<taskA, workerAlive, corruptSeen>>

Next ==
    \/ DecodeCorruptA
    \/ DecodeValidB
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ taskA \in {"pending", "failed"}
    /\ taskB \in {"pending", "succeeded"}
    /\ workerAlive \in BOOLEAN
    /\ corruptSeen \in BOOLEAN
    /\ validSeen \in BOOLEAN

NoBatchAbort ==
    validSeen => taskB = "succeeded"

NoOrphanedFirstTask ==
    corruptSeen => taskA = "failed"

=============================================================================
