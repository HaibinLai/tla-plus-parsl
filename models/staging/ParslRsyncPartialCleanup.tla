--------------------------- MODULE ParslRsyncPartialCleanup ---------------------------
EXTENDS Naturals

(***************************************************************************
 * RSync in-task stage-in failure cleanup.
 *
 * rsync may leave a partial destination when it returns a non-zero status.
 * The current wrapper raises immediately and leaves that path published;
 * USE_FIXED models removing the partial destination before reporting failure.
 ***************************************************************************)

CONSTANT USE_FIXED
VARIABLES state, bytesPublished
vars == <<state, bytesPublished>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ state = "transferring"
    /\ bytesPublished = 1

FailTransfer ==
    /\ state = "transferring"
    /\ state' = "failed"
    /\ bytesPublished' = IF USE_FIXED THEN 0 ELSE bytesPublished

Next == FailTransfer \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in {"transferring", "failed"}
    /\ bytesPublished \in 0..1

FailureCleanupSafety == state = "failed" => bytesPublished = 0
=============================================================================
