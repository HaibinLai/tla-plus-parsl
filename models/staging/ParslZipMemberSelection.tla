--------------------------- MODULE ParslZipMemberSelection ---------------------------
EXTENDS Naturals

(***************************************************************************
 * ZipFileStaging._zip_stage_in calls ZipFile.read(inside_path).  Python's
 * zipfile implementation returns the last matching member when an archive
 * contains duplicate names, so a retry-created duplicate can silently change
 * the bytes delivered to a task.  The current branch permits that ambiguity;
 * the FIXED branch rejects duplicate member names before publication.
 ***************************************************************************)

CONSTANTS MEMBER_COUNT, FIXED

Phases == {"idle", "available", "rejected"}
VARIABLES phase, selected
vars == <<phase, selected>>

Init ==
    /\ MEMBER_COUNT \in 1..2
    /\ FIXED \in BOOLEAN
    /\ phase = "idle"
    /\ selected = 0

ReadMember ==
    /\ phase = "idle"
    /\ IF FIXED /\ MEMBER_COUNT > 1
          THEN /\ phase' = "rejected"
               /\ selected' = 0
          ELSE /\ phase' = "available"
               /\ selected' = MEMBER_COUNT

Next ==
    \/ ReadMember
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ MEMBER_COUNT \in 1..2
    /\ FIXED \in BOOLEAN
    /\ phase \in Phases
    /\ selected \in 0..2

NoAmbiguousRead ==
    phase = "available" => FIXED \/ MEMBER_COUNT = 1

=============================================================================
