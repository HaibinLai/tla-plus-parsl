--------------------------- MODULE ParslSlurmMalformedLine ---------------------------
EXTENDS Naturals

(***************************************************************************
 * SlurmProvider._status expects every non-empty scheduler line to contain a
 * job id and a state token.  A truncated line raises during tuple unpacking
 * and aborts the whole polling pass.  USE_FIXED models skipping malformed
 * lines while retaining the last known local status.
 ***************************************************************************)

CONSTANT USE_FIXED
VARIABLES report, state, localStatus
vars == <<report, state, localStatus>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ report = "truncated"
    /\ state = "idle"
    /\ localStatus = "running"

Poll ==
    /\ state = "idle"
    /\ state' = IF USE_FIXED THEN "ignored" ELSE "crashed"
    /\ UNCHANGED <<report, localStatus>>

Next == Poll \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ report = "truncated"
    /\ state \in {"idle", "ignored", "crashed"}
    /\ localStatus = "running"

MalformedRecordSafety == state # "crashed"
=============================================================================
