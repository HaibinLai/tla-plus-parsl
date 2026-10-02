--------------------------- MODULE ParslAwsTeardownStateCleanup ---------------------------
EXTENDS Naturals

(***************************************************************************
 * AWS provider teardown state-file cleanup.
 *
 * Resource teardown can complete successfully even when the persisted state
 * file has already been removed.  The Current branch performs an unconditional
 * remove and leaks FileNotFoundError; the Fixed branch treats an absent state
 * file as an idempotent cleanup condition.
 ***************************************************************************)

CONSTANTS USE_FIXED, STATE_PRESENT

VARIABLES resources, stateFile, outcome
vars == <<resources, stateFile, outcome>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ STATE_PRESENT \in BOOLEAN
    /\ resources = "active"
    /\ stateFile = STATE_PRESENT
    /\ outcome = "open"

DeleteResources ==
    /\ resources = "active"
    /\ resources' = "deleted"
    /\ UNCHANGED <<stateFile, outcome>>

RemoveStateFile ==
    /\ resources = "deleted"
    /\ IF stateFile
          THEN /\ stateFile' = FALSE
               /\ outcome' = "cleaned"
          ELSE IF USE_FIXED
               THEN /\ UNCHANGED stateFile
                    /\ outcome' = "cleaned"
               ELSE /\ UNCHANGED stateFile
                    /\ outcome' = "raw-file-not-found"
    /\ UNCHANGED resources

Next == DeleteResources \/ RemoveStateFile \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ resources \in {"active", "deleted"}
    /\ stateFile \in BOOLEAN
    /\ outcome \in {"open", "cleaned", "raw-file-not-found"}

CleanupSafety == outcome # "raw-file-not-found"

=============================================================================
