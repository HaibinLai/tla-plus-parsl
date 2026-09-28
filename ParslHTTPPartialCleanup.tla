--------------------------- MODULE ParslHTTPPartialCleanup ---------------------------
EXTENDS Naturals

(***************************************************************************
 * HTTP staging writes response chunks directly to the destination path.
 * If a later chunk fails, the current path leaves the earlier bytes
 * published; the FIXED branch discards the partial file before failure.
 *************************************************************************** *)

CONSTANTS TRANSFER_FAILS, USE_FIXED
VARIABLES state, bytesPublished
vars == <<state, bytesPublished>>

Init ==
    /\ TRANSFER_FAILS \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ state = "fetching"
    /\ bytesPublished = 0

FirstChunk ==
    /\ state = "fetching"
    /\ state' = "streaming"
    /\ bytesPublished' = 1

LaterChunk ==
    /\ state = "streaming"
    /\ TRANSFER_FAILS
    /\ state' = "failed"
    /\ bytesPublished' = IF USE_FIXED THEN 0 ELSE bytesPublished

Complete ==
    /\ state = "streaming"
    /\ ~TRANSFER_FAILS
    /\ state' = "completed"
    /\ UNCHANGED bytesPublished

Next ==
    \/ FirstChunk
    \/ LaterChunk
    \/ Complete
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in {"fetching", "streaming", "failed", "completed"}
    /\ bytesPublished \in Nat

FailurePublicationSafety == state = "failed" => bytesPublished = 0

=============================================================================
