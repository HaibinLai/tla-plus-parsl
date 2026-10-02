--------------------------- MODULE ParslRadicalMasterCountAdmission ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Radical-Pilot master-count admission.
 *
 * ResourceConfig permits masters=0.  The executor can finish start() with
 * an empty master list, but the cyclic selector later computes modulo the
 * list.  The Current branch leaks IndexError on first submit;
 * the Fixed branch rejects the configuration during startup.
 ***************************************************************************)

CONSTANTS USE_FIXED, MASTER_COUNT

VARIABLES startup, selector, outcome
vars == <<startup, selector, outcome>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ MASTER_COUNT \in 0..1
    /\ startup = "new"
    /\ selector = "absent"
    /\ outcome = "none"

Start ==
    /\ startup = "new"
    /\ IF MASTER_COUNT = 0 /\ USE_FIXED
          THEN /\ startup' = "failed"
               /\ selector' = "absent"
          ELSE /\ startup' = "started"
               /\ selector' = IF MASTER_COUNT = 0 THEN "empty" ELSE "ready"
    /\ UNCHANGED outcome

SelectMaster ==
    /\ startup = "started"
    /\ IF selector = "empty"
          THEN outcome' = IF USE_FIXED THEN "rejected" ELSE "raw-index-error"
          ELSE outcome' = "selected"
    /\ UNCHANGED <<startup, selector>>

Next == Start \/ SelectMaster \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ startup \in {"new", "started", "failed"}
    /\ selector \in {"absent", "empty", "ready"}
    /\ outcome \in {"none", "selected", "rejected", "raw-index-error"}

AdmissionSafety == outcome # "raw-index-error"

=============================================================================
