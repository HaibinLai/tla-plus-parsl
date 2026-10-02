--------------------------- MODULE ParslBadStateSubmitRace ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Admission versus executor bad-state race.
 *
 * HTEX submit_payload checks bad_state_is_set before inserting its Future into
 * the task registry.  If failure handling runs between those operations, the
 * Current branch inserts a task after fail-all has finished and leaves it
 * without a terminal result.  The Fixed branch rechecks under the same gate.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES checked, bad, inserted, failed, rejected, taskTerminal
vars == <<checked, bad, inserted, failed, rejected, taskTerminal>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ checked = FALSE
    /\ bad = FALSE
    /\ inserted = FALSE
    /\ failed = FALSE
    /\ rejected = FALSE
    /\ taskTerminal = FALSE

CheckSubmit ==
    /\ ~checked
    /\ ~bad
    /\ checked' = TRUE
    /\ UNCHANGED <<bad, inserted, failed, rejected, taskTerminal>>

EnterBadState ==
    /\ checked
    /\ ~bad
    /\ bad' = TRUE
    /\ failed' = TRUE
    /\ taskTerminal' = inserted
    /\ UNCHANGED <<checked, inserted, rejected>>

FinishSubmit ==
    /\ checked
    /\ IF USE_FIXED /\ bad
          THEN /\ rejected' = TRUE
               /\ inserted' = FALSE
          ELSE /\ inserted' = TRUE
               /\ rejected' = FALSE
    /\ UNCHANGED <<checked, bad, failed, taskTerminal>>

Next == CheckSubmit \/ EnterBadState \/ FinishSubmit \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ checked \in BOOLEAN
    /\ bad \in BOOLEAN
    /\ inserted \in BOOLEAN
    /\ failed \in BOOLEAN
    /\ rejected \in BOOLEAN
    /\ taskTerminal \in BOOLEAN

NoOrphanedSubmit == bad /\ failed /\ ~taskTerminal => ~inserted

=============================================================================
