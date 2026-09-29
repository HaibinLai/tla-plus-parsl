--------------------------- MODULE ParslHtexDuplicateRegistration ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Duplicate HTEX manager registration.
 *
 * Interchange accepts a registration and stores a fresh ManagerRecord under
 * the manager identity.  A second registration for the same identity replaces
 * the old record, including its in-flight task list.  The current branch can
 * therefore lose task ownership without forwarding success or ManagerLost.
 * The fixed branch preserves the existing record until its tasks are resolved.
 *************************************************************************** *)

CONSTANT USE_FIXED
VARIABLES state, inFlight, resultCount
vars == <<state, inFlight, resultCount>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ state = "registered"
    /\ inFlight = 1
    /\ resultCount = 0

DuplicateRegistration ==
    /\ state = "registered"
    /\ state' = "registered-again"
    /\ IF USE_FIXED
          THEN /\ inFlight' = inFlight
               /\ resultCount' = resultCount
          ELSE /\ inFlight' = 0
               /\ resultCount' = resultCount

ResolveTask ==
    /\ state = "registered-again"
    /\ inFlight = 1
    /\ inFlight' = 0
    /\ resultCount' = resultCount + 1
    /\ UNCHANGED state

Next ==
    \/ DuplicateRegistration
    \/ ResolveTask
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ state \in {"registered", "registered-again"}
    /\ inFlight \in 0..1
    /\ resultCount \in Nat

NoTaskLoss == state = "registered-again" => (inFlight = 1 \/ resultCount = 1)

=============================================================================
