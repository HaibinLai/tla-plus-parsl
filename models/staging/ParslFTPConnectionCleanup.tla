--------------------------- MODULE ParslFTPConnectionCleanup ---------------------------
EXTENDS Naturals

(***************************************************************************
 * FTP staging opens a connection, transfers bytes, and calls quit only on
 * the normal path.  A retrbinary failure currently leaves the connection
 * open; the FIXED branch closes it in a finally-equivalent action.
 *************************************************************************** *)

CONSTANTS TRANSFER_FAILS, USE_FIXED
VARIABLES state, connectionOpen
vars == <<state, connectionOpen>>

Init ==
    /\ TRANSFER_FAILS \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ state = "opened"
    /\ connectionOpen = TRUE

Transfer ==
    /\ state = "opened"
    /\ TRANSFER_FAILS
    /\ state' = "failed"
    /\ connectionOpen' = IF USE_FIXED THEN FALSE ELSE TRUE

TransferSuccess ==
    /\ state = "opened"
    /\ ~TRANSFER_FAILS
    /\ state' = "completed"
    /\ connectionOpen' = FALSE

Next ==
    \/ Transfer
    \/ TransferSuccess
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in {"opened", "failed", "completed"}
    /\ connectionOpen \in BOOLEAN

FailureCleanupSafety == state = "failed" => ~connectionOpen

=============================================================================
