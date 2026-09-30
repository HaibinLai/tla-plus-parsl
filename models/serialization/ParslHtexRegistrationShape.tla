--------------------------- MODULE ParslHtexRegistrationShape ---------------------------
EXTENDS Naturals

(***************************************************************************
 * HTEX manager registration-envelope validation.
 *
 * The outer message decoder checks that a registration frame is pickleable
 * and has a type, but the current registration path immediately indexes
 * required fields such as python_v and parsl_v. A missing field therefore
 * escapes as a KeyError. The fixed branch rejects the registration before
 * mutating manager state.
 *)

CONSTANTS VALID_REGISTRATION, USE_FIXED

VARIABLES phase, managerRegistered
vars == <<phase, managerRegistered>>

Init ==
    /\ VALID_REGISTRATION \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ phase = "received"
    /\ managerRegistered = FALSE

ProcessRegistration ==
    /\ phase = "received"
    /\ IF VALID_REGISTRATION \/ USE_FIXED
          THEN /\ phase' = IF VALID_REGISTRATION THEN "registered" ELSE "rejected"
               /\ managerRegistered' = VALID_REGISTRATION
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
