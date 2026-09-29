--------------------------- MODULE ParslSlurmBatchStrict ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Python-version compatibility for Slurm's local ``batched`` helper.
 *
 * On Python versions without itertools.batched, Parsl's fallback accepts a
 * ``strict`` argument but does not reject an incomplete final batch.  The
 * fixed branch enforces the Python 3.12 strict contract.
 *************************************************************************** *)

CONSTANTS INCOMPLETE_FINAL_BATCH, STRICT, USE_FIXED
VARIABLES state
vars == <<state>>

Init ==
    /\ INCOMPLETE_FINAL_BATCH \in BOOLEAN
    /\ STRICT \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ state = "unbatched"

Batch ==
    /\ state = "unbatched"
    /\ state' = IF INCOMPLETE_FINAL_BATCH /\ STRICT /\ USE_FIXED
                   THEN "rejected"
                   ELSE "accepted"

Next ==
    \/ Batch
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ INCOMPLETE_FINAL_BATCH \in BOOLEAN
    /\ STRICT \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ state \in {"unbatched", "accepted", "rejected"}

StrictBatchSafety ==
    state = "accepted" => ~(INCOMPLETE_FINAL_BATCH /\ STRICT)

=============================================================================
