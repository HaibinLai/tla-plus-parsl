--------------------------- MODULE ParslFilesystemRadioAtomicity ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Filesystem monitoring-radio publication.
 *
 * FilesystemRadioSender writes a pickle into tmp/ and atomically renames it
 * into new/.  A reader scans only new/, so it must never observe a partial
 * message.  USE_FIXED models the tmp-plus-rename protocol; the current
 * branch exposes a direct-write publication race.
 ***************************************************************************)

CONSTANT USE_FIXED

FileStates == {"absent", "partial", "complete"}
WriterStates == {"idle", "writing", "published"}
ReaderStates == {"none", "complete", "partial"}

VARIABLES tmpFile, newFile, writer, reader
vars == <<tmpFile, newFile, writer, reader>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ tmpFile = "absent"
    /\ newFile = "absent"
    /\ writer = "idle"
    /\ reader = "none"

BeginWrite ==
    /\ writer = "idle"
    /\ tmpFile = "absent"
    /\ newFile = "absent"
    /\ writer' = "writing"
    /\ IF USE_FIXED
          THEN /\ tmpFile' = "partial"
               /\ UNCHANGED newFile
          ELSE /\ newFile' = "partial"
               /\ UNCHANGED tmpFile
    /\ UNCHANGED reader

FinishWrite ==
    /\ writer = "writing"
    /\ IF USE_FIXED
          THEN /\ tmpFile = "partial"
               /\ tmpFile' = "complete"
               /\ UNCHANGED newFile
          ELSE /\ newFile = "partial"
               /\ newFile' = "complete"
               /\ UNCHANGED tmpFile
    /\ UNCHANGED <<writer, reader>>

PublishFixed ==
    /\ USE_FIXED
    /\ writer = "writing"
    /\ tmpFile = "complete"
    /\ newFile' = "complete"
    /\ tmpFile' = "absent"
    /\ writer' = "published"
    /\ UNCHANGED reader

PublishCurrent ==
    /\ ~USE_FIXED
    /\ writer = "writing"
    /\ newFile = "complete"
    /\ writer' = "published"
    /\ UNCHANGED <<tmpFile, newFile, reader>>

ReadComplete ==
    /\ newFile = "complete"
    /\ reader' = "complete"
    /\ UNCHANGED <<tmpFile, newFile, writer>>

ReadPartial ==
    /\ newFile = "partial"
    /\ reader' = "partial"
    /\ UNCHANGED <<tmpFile, newFile, writer>>

DeleteMessage ==
    /\ reader = "complete"
    /\ newFile = "complete"
    /\ newFile' = "absent"
    /\ reader' = "none"
    /\ UNCHANGED <<tmpFile, writer>>

Next ==
    \/ BeginWrite
    \/ FinishWrite
    \/ PublishFixed
    \/ PublishCurrent
    \/ ReadComplete
    \/ ReadPartial
    \/ DeleteMessage
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ tmpFile \in FileStates
    /\ newFile \in FileStates
    /\ writer \in WriterStates
    /\ reader \in ReaderStates

ReaderOnlyComplete ==
    reader # "partial"

AtomicPublication ==
    USE_FIXED => newFile # "partial"

=============================================================================
SPECIFICATION Spec

INVARIANTS
    TypeOK
    ReaderOnlyComplete
    AtomicPublication
