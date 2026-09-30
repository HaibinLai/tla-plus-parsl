--------------------------- MODULE ParslHtexRegistrationTypes ---------------------------
EXTENDS Naturals

(***************************************************************************
 * HTEX registration metadata is decoded from pickle before the registration
 * branch accesses version fields.  The current branch calls ``rsplit`` on
 * python_v without checking that it is a string.  USE_FIXED rejects a
 * malformed typed envelope before manager state changes.
 ***************************************************************************)

CONSTANTS VALID_PYTHON_VERSION, USE_FIXED

VARIABLES phase, managerRegistered
vars == <<phase, managerRegistered>>

Init ==
    /\ VALID_PYTHON_VERSION \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ phase = "received"
    /\ managerRegistered = FALSE

ProcessRegistration ==
    /\ phase = "received"
    /\ IF VALID_PYTHON_VERSION
          THEN /\ phase' = "registered"
               /\ managerRegistered' = TRUE
          ELSE IF USE_FIXED
               THEN /\ phase' = "rejected"
                    /\ UNCHANGED managerRegistered
               ELSE /\ phase' = "crashed"
                    /\ UNCHANGED managerRegistered

Next == ProcessRegistration \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ phase \in {"received", "registered", "rejected", "crashed"}
    /\ managerRegistered \in BOOLEAN

RegistrationIsolation == phase # "crashed"
RegistrationStateSafety == managerRegistered => phase = "registered"

=============================================================================
