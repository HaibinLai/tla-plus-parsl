--------------------------- MODULE ParslMonitoringDBRetry ---------------------------
EXTENDS Naturals

(***************************************************************************
 * DatabaseManager._insert retries SQLAlchemy OperationalError after rollback,
 * while a non-operational error is dropped.  A transient lock therefore can
 * recover on the next insert attempt without duplicating the logical event.
 *************************************************************************** *)

CONSTANT ERROR_KIND

Errors == {"none", "operational", "integrity"}
States == {"queued", "writing", "retrying", "stored", "dropped"}
VARIABLES state, attempts, rows
vars == <<state, attempts, rows>>

Init ==
    /\ ERROR_KIND \in Errors
    /\ state = "queued"
    /\ attempts = 0
    /\ rows = 0

BeginInsert ==
    /\ state = "queued"
    /\ state' = "writing"
    /\ UNCHANGED <<attempts, rows>>

OperationalFailure ==
    /\ state = "writing"
    /\ ERROR_KIND = "operational"
    /\ attempts = 0
    /\ state' = "retrying"
    /\ attempts' = 1
    /\ UNCHANGED rows

RetryInsert ==
    /\ state = "retrying"
    /\ state' = "writing"
    /\ UNCHANGED <<attempts, rows>>

InsertSuccess ==
    /\ state = "writing"
    /\ ERROR_KIND \in {"none", "operational"}
    /\ state' = "stored"
    /\ rows' = 1
    /\ UNCHANGED attempts

IntegrityFailure ==
    /\ state = "writing"
    /\ ERROR_KIND = "integrity"
    /\ state' = "dropped"
    /\ UNCHANGED <<attempts, rows>>

Next ==
    \/ BeginInsert
    \/ OperationalFailure
    \/ RetryInsert
    \/ InsertSuccess
    \/ IntegrityFailure
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in States
    /\ attempts \in 0..1
    /\ rows \in 0..1

SingleRowSafety ==
    rows <= 1

IntegrityDropSafety ==
    ERROR_KIND = "integrity" => state \in {"queued", "writing", "dropped"}

=============================================================================
