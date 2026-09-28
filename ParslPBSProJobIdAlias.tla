--------------------------- MODULE ParslPBSProJobIdAlias ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Bounded model of PBSProProvider._status job-id normalization.
 *
 * PBS Pro can report both a short id such as "42" and a fully qualified id
 * such as "42.server". The current parser maps a reported id to the first
 * locally known id having that prefix. Two distinct JSON keys can therefore
 * select the same local resource. The first record removes that resource
 * from jobs_missing and the second list.remove raises ValueError. The FIXED
 * branch treats normalized records idempotently.
 *************************************************************************** *)

CONSTANTS ALIAS_COLLISION, USE_FIXED
VARIABLES state, jobMissing, normalizedRecords, duplicateIgnored
vars == <<state, jobMissing, normalizedRecords, duplicateIgnored>>

Init ==
    /\ ALIAS_COLLISION \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ state = "polling"
    /\ jobMissing = TRUE
    /\ normalizedRecords = 0
    /\ duplicateIgnored = FALSE

HandleShortId ==
    /\ state = "polling"
    /\ state' = "short-normalized"
    /\ jobMissing' = FALSE
    /\ normalizedRecords' = 1
    /\ UNCHANGED duplicateIgnored

HandleSecondRecord ==
    /\ state = "short-normalized"
    /\ ALIAS_COLLISION
    /\ IF USE_FIXED
          THEN /\ state' = "updated"
               /\ normalizedRecords' = 2
               /\ duplicateIgnored' = TRUE
          ELSE /\ state' = "crashed"
               /\ normalizedRecords' = 1
               /\ UNCHANGED duplicateIgnored
    /\ UNCHANGED jobMissing

FinishUnique ==
    /\ state = "short-normalized"
    /\ ~ALIAS_COLLISION
    /\ state' = "updated"
    /\ normalizedRecords' = 1
    /\ UNCHANGED <<jobMissing, duplicateIgnored>>

Next ==
    \/ HandleShortId
    \/ HandleSecondRecord
    \/ FinishUnique
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in {"polling", "short-normalized", "updated", "crashed"}
    /\ jobMissing \in BOOLEAN
    /\ normalizedRecords \in 0..2
    /\ duplicateIgnored \in BOOLEAN

AliasSafety == state # "crashed"

MissingBookkeepingSafety ==
    normalizedRecords > 0 => ~jobMissing

=============================================================================
