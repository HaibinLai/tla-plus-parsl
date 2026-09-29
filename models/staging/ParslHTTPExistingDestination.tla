--------------------------- MODULE ParslHTTPExistingDestination ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Replacement of an already-valid stage-in file.
 *
 * HTTPInTaskStaging writes directly to file.local_path with ``wb``.  Opening
 * the final path truncates the previous bytes before the response stream has
 * completed.  A failed stream therefore loses a valid old version.  The
 * fixed branch writes a temporary path and preserves the old version until
 * an atomic replacement is possible.
 ***************************************************************************)

CONSTANTS TRANSFER_FAILS, USE_FIXED
DESTINATION_STATES == {"old", "partial", "new", "absent"}

VARIABLES state, destination
vars == <<state, destination>>

Init ==
    /\ TRANSFER_FAILS \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ state = "fetching"
    /\ destination = "old"

OpenDestination ==
    /\ state = "fetching"
    /\ state' = "streaming"
    /\ destination' = IF USE_FIXED THEN "old" ELSE "partial"

ReceiveChunk ==
    /\ state = "streaming"
    /\ state' = "streaming"
    /\ UNCHANGED destination

FailTransfer ==
    /\ state = "streaming"
    /\ TRANSFER_FAILS
    /\ state' = "failed"
    /\ destination' = IF USE_FIXED THEN "old" ELSE destination

PublishReplacement ==
    /\ state = "streaming"
    /\ ~TRANSFER_FAILS
    /\ state' = "completed"
    /\ destination' = "new"

Next ==
    \/ OpenDestination
    \/ ReceiveChunk
    \/ FailTransfer
    \/ PublishReplacement
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in {"fetching", "streaming", "failed", "completed"}
    /\ destination \in DESTINATION_STATES

FailurePreservesPreviousVersion ==
    state = "failed" => destination = "old"

SuccessfulTransferPublishesNewVersion ==
    state = "completed" => destination = "new"

=============================================================================
