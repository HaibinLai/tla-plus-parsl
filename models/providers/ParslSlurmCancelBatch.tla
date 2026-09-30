-------------------------- MODULE ParslSlurmCancelBatch --------------------------
EXTENDS Naturals

(***************************************************************************
 * SlurmProvider.cancel with a known ID followed by a stale ID.
 *
 * The scheduler command succeeds, so the current implementation updates the
 * known resource before indexing the stale one and raising KeyError. The
 * fixed branch treats the stale entry as an idempotent miss and completes the
 * batch while preserving the successful prefix.
 ***************************************************************************)

CONSTANT USE_FIXED
VARIABLE operation, knownState
vars == <<operation, knownState>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ operation = "ready"
    /\ knownState = "running"

CancelBatch ==
    /\ operation = "ready"
    /\ knownState' = "cancelled"
    /\ operation' = IF USE_FIXED THEN "done" ELSE "failed"

Next == CancelBatch \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ operation \in {"ready", "done", "failed"}
    /\ knownState \in {"running", "cancelled"}

NoBatchAbort == operation # "failed"
PrefixPreserved == operation \in {"done", "failed"} => knownState = "cancelled"

=============================================================================
