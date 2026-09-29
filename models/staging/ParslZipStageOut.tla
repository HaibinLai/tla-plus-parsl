--------------------------- MODULE ParslZipStageOut ---------------------------
EXTENDS Naturals

(***************************************************************************
 * ZipFileStaging.stage_out appends the source to the archive and removes the
 * source only afterwards.  If remove fails, a retry can append a second
 * member.  This leaves duplicate archive entries and emits a duplicate-name
 * warning on retry.  The FIXED branch models an idempotent replacement of the
 * archive member.
 *************************************************************************** *)

CONSTANTS REMOVE_SUCCEEDS, SOURCE_CHANGED, FIXED

Phases == {"idle", "archived", "failed", "completed"}
VARIABLES phase, sourceVersion, archiveEntries, visibleVersion, sourcePresent
vars == <<phase, sourceVersion, archiveEntries, visibleVersion, sourcePresent>>

Init ==
    /\ REMOVE_SUCCEEDS \in BOOLEAN
    /\ SOURCE_CHANGED \in BOOLEAN
    /\ FIXED \in BOOLEAN
    /\ phase = "idle"
    /\ sourceVersion = 1
    /\ archiveEntries = 0
    /\ visibleVersion = 0
    /\ sourcePresent = TRUE

WriteArchive ==
    /\ phase \in {"idle", "failed"}
    /\ sourcePresent
    /\ archiveEntries < 2
    /\ archiveEntries' = IF FIXED /\ archiveEntries > 0
                              THEN 1 ELSE archiveEntries + 1
    /\ visibleVersion' = sourceVersion
    /\ phase' = "archived"
    /\ UNCHANGED <<sourceVersion, sourcePresent>>

RemoveSource ==
    /\ phase = "archived"
    /\ IF REMOVE_SUCCEEDS
          THEN /\ phase' = "completed"
               /\ sourcePresent' = FALSE
          ELSE /\ phase' = "failed"
               /\ UNCHANGED sourcePresent
    /\ UNCHANGED <<sourceVersion, archiveEntries, visibleVersion>>

ModifySourceBeforeRetry ==
    /\ phase = "failed"
    /\ SOURCE_CHANGED
    /\ sourceVersion' = 2
    /\ UNCHANGED <<phase, archiveEntries, visibleVersion, sourcePresent>>

Next ==
    \/ WriteArchive
    \/ RemoveSource
    \/ ModifySourceBeforeRetry
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ phase \in Phases
    /\ sourceVersion \in {1, 2}
    /\ archiveEntries \in 0..2
    /\ visibleVersion \in 0..2
    /\ sourcePresent \in BOOLEAN

ArchiveSafety ==
    phase = "completed" => archiveEntries > 0

NoDuplicateArchiveEntry ==
    FIXED \/ archiveEntries <= 1

=============================================================================
