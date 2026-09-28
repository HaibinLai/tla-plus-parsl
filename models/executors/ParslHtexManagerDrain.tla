--------------------------- MODULE ParslHtexManagerDrain ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Interchange.expire_drained_managers and stale manager IDs.
 *
 * The current implementation indexes _ready_managers directly for every ID
 * in interesting_managers.  A stale ID can therefore raise KeyError before
 * the drain pass completes.  USE_FIXED models an existence guard.  For a
 * present, draining manager with no tasks, both paths send the drained reply
 * and remove the manager from the ready and interesting sets.
 ***************************************************************************)

CONSTANTS STALE_ID, USE_FIXED

VARIABLES ready, interesting, draining, tasks, sent, state
vars == <<ready, interesting, draining, tasks, sent, state>>

Init ==
    /\ STALE_ID \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ ready = ~STALE_ID
    /\ interesting = TRUE
    /\ draining = TRUE
    /\ tasks = 0
    /\ sent = FALSE
    /\ state = "ready"

ExpireDrained ==
    /\ state = "ready"
    /\ interesting
    /\ IF STALE_ID /\ ~USE_FIXED
          THEN /\ state' = "crashed"
               /\ UNCHANGED <<ready, interesting, draining, tasks, sent>>
          ELSE IF STALE_ID /\ USE_FIXED
               THEN /\ state' = "stale-ignored"
                    /\ interesting' = FALSE
                    /\ UNCHANGED <<ready, draining, tasks, sent>>
               ELSE /\ state' = "removed"
                    /\ ready' = FALSE
                    /\ interesting' = FALSE
                    /\ sent' = TRUE
                    /\ UNCHANGED <<draining, tasks>>

Next ==
    \/ ExpireDrained
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ ready \in BOOLEAN
    /\ interesting \in BOOLEAN
    /\ draining \in BOOLEAN
    /\ tasks \in Nat
    /\ sent \in BOOLEAN
    /\ state \in {"ready", "crashed", "stale-ignored", "removed"}

NoCrash == state # "crashed"

DrainRemovalSafety ==
    state = "removed" =>
        /\ ~ready
        /\ ~interesting
        /\ sent

StaleGuardSafety ==
    STALE_ID /\ USE_FIXED /\ state = "stale-ignored" => ~interesting

=============================================================================
