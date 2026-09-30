--------------------------- MODULE ParslMonitoringForeignKey ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Monitoring STATUS rows declare a run_id foreign key to WORKFLOW.  The
 * current SQLite engine does not enable SQLite foreign-key enforcement, so a
 * status row can be stored without its workflow parent.  USE_FIXED models
 * enabling the constraint before inserting the row.
 ***************************************************************************)

CONSTANTS PARENT_PRESENT, USE_FIXED
VARIABLES state, rows
vars == <<state, rows>>

Init ==
    /\ PARENT_PRESENT \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ state = "queued"
    /\ rows = 0

InsertStatus ==
    /\ state = "queued"
    /\ (PARENT_PRESENT \/ ~USE_FIXED)
    /\ state' = "stored"
    /\ rows' = 1

RejectOrphan ==
    /\ state = "queued"
    /\ ~PARENT_PRESENT
    /\ USE_FIXED
    /\ state' = "rejected"
    /\ rows' = 0

Next ==
    \/ InsertStatus
    \/ RejectOrphan
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ PARENT_PRESENT \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ state \in {"queued", "stored", "rejected"}
    /\ rows \in 0..1

ForeignKeySafety == ~PARENT_PRESENT => state # "stored"
StoredRowSafety == state = "stored" => rows = 1

=============================================================================
