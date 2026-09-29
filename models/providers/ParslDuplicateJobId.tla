--------------------------- MODULE ParslDuplicateJobId ---------------------------
EXTENDS Naturals

(***************************************************************************
 * BlockProviderExecutor scale-out job ownership.
 *
 * scale_out_facade records blocks_to_job_id and job_ids_to_block after each
 * provider submission.  If a provider returns the same job ID twice, the
 * reverse map currently overwrites the first block.  The fixed branch rejects
 * duplicate ownership before publishing the second block.
 ***************************************************************************)

CONSTANT USE_FIXED

Phases == {"empty", "one", "two", "rejected", "corrupted"}

VARIABLES phase, forwardCount, reverseCount
vars == <<phase, forwardCount, reverseCount>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ phase = "empty"
    /\ forwardCount = 0
    /\ reverseCount = 0

LaunchFirst ==
    /\ phase = "empty"
    /\ phase' = "one"
    /\ forwardCount' = 1
    /\ reverseCount' = 1

LaunchDuplicateCurrent ==
    /\ ~USE_FIXED
    /\ phase = "one"
    /\ phase' = "corrupted"
    /\ forwardCount' = 2
    /\ reverseCount' = 1

RejectDuplicateFixed ==
    /\ USE_FIXED
    /\ phase = "one"
    /\ phase' = "rejected"
    /\ UNCHANGED <<forwardCount, reverseCount>>

Next ==
    \/ LaunchFirst
    \/ LaunchDuplicateCurrent
    \/ RejectDuplicateFixed
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ phase \in Phases
    /\ forwardCount \in 0..2
    /\ reverseCount \in 0..2

NoLostJobOwnership ==
    forwardCount = 2 => reverseCount = 2

=============================================================================
