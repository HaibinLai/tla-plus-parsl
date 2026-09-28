--------------------------- MODULE ParslMonitoringBatchAtomicity ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Batch insert atomicity at DatabaseManager._insert.
 *
 * Database.insert uses one SQLAlchemy bulk insert and one commit for the
 * whole batch. If a duplicate STATUS key is present, the transaction rolls
 * back; the current generic exception handler then drops the valid messages
 * in the same batch as well. The FIXED branch represents per-message
 * duplicate handling or a retryable split that preserves valid events.
 *************************************************************************** *)

CONSTANTS DUPLICATE_PRESENT, USE_FIXED
VARIABLES state, attempted, validPersisted, duplicateIgnored
vars == <<state, attempted, validPersisted, duplicateIgnored>>

Init ==
    /\ DUPLICATE_PRESENT \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ state = "idle"
    /\ attempted = FALSE
    /\ validPersisted = FALSE
    /\ duplicateIgnored = FALSE

InsertBatch ==
    /\ state = "idle"
    /\ attempted' = TRUE
    /\ IF DUPLICATE_PRESENT /\ ~USE_FIXED
          THEN /\ state' = "rolled-back"
               /\ validPersisted' = FALSE
               /\ duplicateIgnored' = FALSE
          ELSE /\ state' = "committed"
               /\ validPersisted' = TRUE
               /\ duplicateIgnored' = DUPLICATE_PRESENT

Next ==
    \/ InsertBatch
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in {"idle", "committed", "rolled-back"}
    /\ attempted \in BOOLEAN
    /\ validPersisted \in BOOLEAN
    /\ duplicateIgnored \in BOOLEAN

ValidMessagePreserved ==
    attempted => validPersisted

=============================================================================
