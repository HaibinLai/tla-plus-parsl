--------------------------- MODULE ParslFTPPartialCleanup ---------------------------
EXTENDS Naturals

(***************************************************************************
 * FTP stage-in writes response bytes directly to the destination path.
 * If retrbinary fails after a partial write, the current implementation
 * leaves those bytes visible.  USE_FIXED models removing the partial file.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES phase, bytesVisible
vars == <<phase, bytesVisible>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ phase = "fetching"
    /\ bytesVisible = 0

FirstChunk ==
    /\ phase = "fetching"
    /\ phase' = "streaming"
    /\ bytesVisible' = 1

TransferFailure ==
    /\ phase = "streaming"
    /\ phase' = "failed"
    /\ bytesVisible' = IF USE_FIXED THEN 0 ELSE bytesVisible

Next ==
    \/ FirstChunk
    \/ TransferFailure
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ phase \in {"fetching", "streaming", "failed"}
    /\ bytesVisible \in 0..1

FailurePublicationSafety ==
    phase = "failed" => bytesVisible = 0

=============================================================================
