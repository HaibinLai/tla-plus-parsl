--------------------------- MODULE ParslTorqueStatusFailure ---------------------------
EXTENDS Naturals

(***************************************************************************
 * TorqueProvider._status parses qstat stdout without checking its return
 * code.  A failed command can therefore apply stale scheduler output to a
 * live local resource.  USE_FIXED models returning early and preserving the
 * last known state when qstat fails.
 ***************************************************************************)

CONSTANT USE_FIXED
VARIABLES command, state, jobStatus
vars == <<command, state, jobStatus>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ command = "failed"
    /\ state = "idle"
    /\ jobStatus = "running"

Poll ==
    /\ state = "idle"
    /\ state' = IF USE_FIXED THEN "preserved" ELSE "updated-stale"
    /\ jobStatus' = IF USE_FIXED THEN jobStatus ELSE "completed"
    /\ UNCHANGED command

Next == Poll \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ command = "failed"
    /\ state \in {"idle", "preserved", "updated-stale"}
    /\ jobStatus \in {"running", "completed"}

FailurePreservation == command = "failed" => jobStatus = "running"
=============================================================================
