--------------------------- MODULE ParslHTTPConnectionCleanup ---------------------------
EXTENDS Naturals

(***************************************************************************
 * HTTP stage-in response cleanup.
 *
 * HTTPInTaskStaging obtains a streaming requests.Response and iterates its
 * chunks.  If iteration fails, the current wrapper escapes without closing
 * the response.  USE_FIXED models a finally-equivalent response close.
 *************************************************************************** *)

CONSTANTS TRANSFER_FAILS, USE_FIXED
VARIABLES state, responseOpen
vars == <<state, responseOpen>>

Init ==
    /\ TRANSFER_FAILS \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ state = "opened"
    /\ responseOpen = TRUE

Transfer ==
    /\ state = "opened"
    /\ TRANSFER_FAILS
    /\ state' = "failed"
    /\ responseOpen' = IF USE_FIXED THEN FALSE ELSE TRUE

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
    /\ state \in {"opened", "failed", "completed"}
    /\ responseOpen \in BOOLEAN

FailureCleanupSafety == state = "failed" => ~responseOpen

=============================================================================
