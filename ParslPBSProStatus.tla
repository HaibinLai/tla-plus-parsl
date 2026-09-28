--------------------------- MODULE ParslPBSProStatus ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Bounded model of PBSProProvider._status JSON job handling.
 *
 * PBS Pro status output can contain a job id which is not present in the
 * provider's local resource map.  The current implementation indexes that
 * id directly; the fixed path ignores foreign jobs and preserves local state.
 ***************************************************************************)

CONSTANTS FOREIGN_JOB, USE_FIXED

States == {"idle", "polling", "updated", "crashed"}

VARIABLES state, knownStatus
vars == <<state, knownStatus>>

Init ==
    /\ FOREIGN_JOB \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ state = "idle"
    /\ knownStatus = "running"

BeginPoll ==
    /\ state = "idle"
    /\ state' = "polling"
    /\ UNCHANGED knownStatus

HandleJob ==
    /\ state = "polling"
    /\ IF FOREIGN_JOB /\ ~USE_FIXED THEN
           /\ state' = "crashed"
           /\ UNCHANGED knownStatus
       ELSE IF FOREIGN_JOB /\ USE_FIXED THEN
           /\ state' = "updated"
           /\ UNCHANGED knownStatus
       ELSE
           /\ state' = "updated"
           /\ knownStatus' = "running"

Next ==
    \/ BeginPoll
    \/ HandleJob
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in States
    /\ knownStatus = "running"

NoForeignCrash == state # "crashed"

=============================================================================
