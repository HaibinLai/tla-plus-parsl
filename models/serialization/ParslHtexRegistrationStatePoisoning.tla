--------------------------- MODULE ParslHtexRegistrationStatePoisoning ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Interchange builds a ManagerRecord and then calls new_rec.update(meta).
 * A pickleable registration can therefore overwrite reserved fields such as
 * tasks with an invalid value before the manager is admitted.  The current
 * branch accepts that poisoned record; the FIXED branch rejects reserved-field
 * overrides before publishing manager state.
 ***************************************************************************)

CONSTANTS RESERVED_OVERRIDE, FIXED
VARIABLES phase, tasksShape
vars == <<phase, tasksShape>>

Init ==
    /\ RESERVED_OVERRIDE \in BOOLEAN
    /\ FIXED \in BOOLEAN
    /\ phase = "received"
    /\ tasksShape = "list"

ProcessRegistration ==
    /\ phase = "received"
    /\ IF RESERVED_OVERRIDE /\ FIXED
          THEN /\ phase' = "rejected"
               /\ tasksShape' = "list"
          ELSE /\ phase' = "registered"
               /\ tasksShape' = IF RESERVED_OVERRIDE THEN "poison" ELSE "list"

Next ==
    \/ ProcessRegistration
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ RESERVED_OVERRIDE \in BOOLEAN
    /\ FIXED \in BOOLEAN
    /\ phase \in {"received", "registered", "rejected"}
    /\ tasksShape \in {"list", "poison"}

RegistrationStateSafety == phase = "registered" => tasksShape = "list"

=============================================================================
