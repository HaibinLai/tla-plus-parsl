--------------------------- MODULE ParslLocalPidAdmission ---------------------------
EXTENDS Naturals, Integers

(***************************************************************************
 * LocalProvider.submit parses the launcher PID as an integer but currently
 * accepts zero or negative values.  Such values are not valid process IDs for
 * a managed worker; in particular os.kill(0, 0) tests the caller's process
 * group.  USE_FIXED rejects non-positive PID output before publishing a
 * running resource.
 ***************************************************************************)

CONSTANT PID_KIND, USE_FIXED
VARIABLES phase, resource, outcome
vars == <<phase, resource, outcome>>

Init ==
    /\ PID_KIND \in {"zero", "negative", "positive"}
    /\ USE_FIXED \in BOOLEAN
    /\ phase = "launcher-returned"
    /\ resource = "absent"
    /\ outcome = "waiting"

RecordPID ==
    /\ phase = "launcher-returned"
    /\ phase' = "complete"
    /\ resource' = IF USE_FIXED /\ PID_KIND # "positive"
                      THEN "rejected" ELSE "running"
    /\ outcome' = IF USE_FIXED /\ PID_KIND # "positive"
                    THEN "controlled-rejection" ELSE "published"

Next == RecordPID \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ phase \in {"launcher-returned", "complete"}
    /\ resource \in {"absent", "running", "rejected"}
    /\ outcome \in {"waiting", "published", "controlled-rejection"}

PidAdmissionSafety ==
    phase = "complete" /\ resource = "running" => PID_KIND = "positive"

=============================================================================
