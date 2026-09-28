--------------------------- MODULE ParslSlurmStatus ---------------------------
EXTENDS Naturals

(***************************************************************************
 * SlurmProvider._status indexes every reported job id into its local
 * resources map.  A foreign scheduler line therefore raises KeyError in the
 * current implementation; the fixed path ignores that line.
 *************************************************************************** *)

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

HandleReportedJob ==
    /\ state = "polling"
    /\ IF FOREIGN_JOB /\ ~USE_FIXED THEN
           /\ state' = "crashed"
           /\ UNCHANGED knownStatus
       ELSE
           /\ state' = "updated"
           /\ UNCHANGED knownStatus

Next ==
    \/ BeginPoll
    \/ HandleReportedJob
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in States
    /\ knownStatus = "running"

NoForeignCrash == state # "crashed"

=============================================================================
