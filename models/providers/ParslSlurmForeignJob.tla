--------------------------- MODULE ParslSlurmForeignJob ---------------------------
EXTENDS Naturals

(***************************************************************************
 * SlurmProvider._status receives scheduler records that are not necessarily
 * in its local resource map.  The current path indexes every reported job id
 * directly, so a foreign or already-forgotten job raises KeyError and stops
 * polling.  USE_FIXED models ignoring such records while preserving local
 * state.
 ***************************************************************************)

CONSTANT USE_FIXED
VARIABLES report, state, localStatus
vars == <<report, state, localStatus>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ report = "foreign"
    /\ state = "idle"
    /\ localStatus = "running"

Poll ==
    /\ state = "idle"
    /\ state' = IF USE_FIXED THEN "ignored" ELSE "crashed"
    /\ UNCHANGED <<report, localStatus>>

Next == Poll \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ report = "foreign"
    /\ state \in {"idle", "ignored", "crashed"}
    /\ localStatus = "running"

ForeignRecordSafety == state # "crashed"
=============================================================================
