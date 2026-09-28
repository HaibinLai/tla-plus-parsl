--------------------------- MODULE ParslSlurmDuplicateStatus ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Slurm status polling tracks missing jobs in a set.  Duplicate scheduler
 * records therefore remove the same job twice in the current implementation.
 * The FIXED branch makes this bookkeeping idempotent.
 *************************************************************************** *)

CONSTANTS DUPLICATE_LINE, USE_FIXED
VARIABLES state, jobMissing, duplicateIgnored
vars == <<state, jobMissing, duplicateIgnored>>

Init ==
    /\ DUPLICATE_LINE \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ state = "polling"
    /\ jobMissing = TRUE
    /\ duplicateIgnored = FALSE

HandleFirstLine ==
    /\ state = "polling"
    /\ state' = "seen"
    /\ jobMissing' = FALSE
    /\ UNCHANGED duplicateIgnored

HandleSecondLine ==
    /\ state = "seen"
    /\ DUPLICATE_LINE
    /\ IF USE_FIXED
          THEN /\ state' = "updated"
               /\ duplicateIgnored' = TRUE
          ELSE /\ state' = "crashed"
               /\ UNCHANGED duplicateIgnored
    /\ UNCHANGED jobMissing

FinishUnique ==
    /\ state = "seen"
    /\ ~DUPLICATE_LINE
    /\ state' = "updated"
    /\ UNCHANGED <<jobMissing, duplicateIgnored>>

Next ==
    \/ HandleFirstLine
    \/ HandleSecondLine
    \/ FinishUnique
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in {"polling", "seen", "updated", "crashed"}
    /\ jobMissing \in BOOLEAN
    /\ duplicateIgnored \in BOOLEAN

DuplicateSafety == state # "crashed"

=============================================================================
