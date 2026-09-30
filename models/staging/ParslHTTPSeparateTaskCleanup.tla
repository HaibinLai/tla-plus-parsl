--------------------------- MODULE ParslHTTPSeparateTaskCleanup ---------------------------
EXTENDS Naturals

(***************************************************************************
 * HTTPSeparateTaskStaging._http_stage_in has its own streaming response
 * path, separate from HTTPInTaskStaging.in_task_transfer_wrapper.  The
 * current helper also leaves a response open when iteration fails.  FIXED
 * represents closing the response on both success and failure.
 ***************************************************************************)

CONSTANTS PATH, TRANSFER_FAILS, FIXED
VARIABLES state, responseOpen
vars == <<state, responseOpen>>

Init ==
    /\ PATH = "separate_task"
    /\ TRANSFER_FAILS \in BOOLEAN
    /\ FIXED \in BOOLEAN
    /\ state = "opened"
    /\ responseOpen = TRUE

Transfer ==
    /\ state = "opened"
    /\ TRANSFER_FAILS
    /\ state' = "failed"
    /\ responseOpen' = IF FIXED THEN FALSE ELSE TRUE

TransferSuccess ==
    /\ state = "opened"
    /\ ~TRANSFER_FAILS
    /\ state' = "completed"
    /\ responseOpen' = FALSE

Next ==
    \/ Transfer
    \/ TransferSuccess
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ PATH = "separate_task"
    /\ TRANSFER_FAILS \in BOOLEAN
    /\ FIXED \in BOOLEAN
    /\ state \in {"opened", "failed", "completed"}
    /\ responseOpen \in BOOLEAN

FailureCleanupSafety == state = "failed" => ~responseOpen

=============================================================================
