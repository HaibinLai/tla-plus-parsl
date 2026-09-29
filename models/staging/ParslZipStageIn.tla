--------------------------- MODULE ParslZipStageIn ---------------------------
EXTENDS Naturals

(***************************************************************************
 * ZipFileStaging.stage_in reads an archive member and then writes directly
 * to the requested output path.  A write failure can therefore expose a
 * partial output file.  The FIXED branch represents writing a temporary file
 * followed by an atomic publish.
 *************************************************************************** *)

CONSTANTS ARCHIVE_VALID, WRITE_SUCCEEDS, FIXED

Phases == {"idle", "reading", "writing", "available", "failed"}
VisibleStates == {"none", "partial", "complete"}
VARIABLES phase, visible
vars == <<phase, visible>>

Init ==
    /\ ARCHIVE_VALID \in BOOLEAN
    /\ WRITE_SUCCEEDS \in BOOLEAN
    /\ FIXED \in BOOLEAN
    /\ phase = "idle"
    /\ visible = "none"

OpenArchive ==
    /\ phase = "idle"
    /\ IF ARCHIVE_VALID
          THEN phase' = "writing"
          ELSE phase' = "failed"
    /\ UNCHANGED visible

WriteOutput ==
    /\ phase = "writing"
    /\ IF WRITE_SUCCEEDS
          THEN /\ phase' = "available"
               /\ visible' = "complete"
          ELSE IF FIXED
               THEN /\ phase' = "failed"
                    /\ visible' = "none"
               ELSE /\ phase' = "failed"
                    /\ visible' = "partial"

Next ==
    \/ OpenArchive
    \/ WriteOutput
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ phase \in Phases
    /\ visible \in VisibleStates

CorruptArchiveSafety ==
    ~ARCHIVE_VALID => visible = "none"

AtomicPublishSafety ==
    phase = "failed" => visible = "none"

=============================================================================
